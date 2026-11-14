import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grocery_item.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class GroceryOverviewStats {
  final int totalStores;
  final double totalUdhaar;
  final double totalChukaya;
  final double netPending;
  final int settledStoresCount;
  final int pendingStoresCount;

  GroceryOverviewStats({
    required this.totalStores,
    required this.totalUdhaar,
    required this.totalChukaya,
    required this.netPending,
    required this.settledStoresCount,
    required this.pendingStoresCount,
  });
}

class GroceryService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _kCachedStores = 'msm_cache_grocery_stores';
  static const String _kCachedEntriesPrefix = 'msm_cache_grocery_entries_';
  static const String _kPendingEntries = 'msm_cache_grocery_pending_entries';
  static const String _kPendingStores = 'msm_cache_grocery_pending_stores';
  static const String _kPendingDeletes = 'msm_cache_grocery_pending_deletes';

  static List<GroceryStore> cachedStores = [];
  static final Map<String, List<GroceryEntry>> cachedEntriesByStore = {};
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  static bool _initialized = false;

  /// Helper: Generate RFC 4122 v4 UUID locally without third-party packages
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Initialize local offline cache & listen to connectivity changes
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kCachedStores);
      if (str != null) {
        final List<dynamic> list = jsonDecode(str);
        cachedStores = list.map((e) => GroceryStore.fromJson(e)).toList();
      }

      // Preload entries for cached stores from disk
      for (final s in cachedStores) {
        final entryStr = prefs.getString('$_kCachedEntriesPrefix${s.id}');
        if (entryStr != null) {
          final List<dynamic> eList = jsonDecode(entryStr);
          cachedEntriesByStore[s.id] = eList.map((e) => GroceryEntry.fromJson(e)).toList();
        }
      }

      dataVersion.value++;

      // Listen for reconnect to flush offline queue
      ConnectivityService().isOnline.addListener(() async {
        if (ConnectivityService().isOnline.value) {
          await syncPending();
          await fetchStores();
        }
      });

      // Background cloud fetch if online
      if (ConnectivityService().isOnline.value) {
        syncPending().then((_) => fetchStores());
      }
    } catch (e) {
      debugPrint('GroceryService initialize notice: $e');
    }
  }

  /// Save stores to local cache
  static Future<void> _saveStoresCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(cachedStores.map((s) => s.toJson()).toList());
      await prefs.setString(_kCachedStores, str);
    } catch (_) {}
  }

  /// Save entries of a specific store to local cache
  static Future<void> _saveEntriesCache(String storeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = cachedEntriesByStore[storeId] ?? [];
      final str = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString('$_kCachedEntriesPrefix$storeId', str);
    } catch (_) {}
  }

  /// Fetch all grocery stores with offline fallback
  static Future<List<GroceryStore>> fetchStores() async {
    if (!ConnectivityService().isOnline.value) {
      return cachedStores;
    }

    try {
      isSyncing.value = true;
      // 1. Flush any pending offline changes first before querying
      await syncPending();

      final userId = AuthService.currentUserId;
      var storeQuery = _client.from('grocery_stores').select('*');
      if (userId != null) {
        storeQuery = storeQuery.eq('user_id', userId);
      }
      final storeRows = await storeQuery.order('created_at', ascending: false);

      var entryQuery = _client.from('grocery_entries').select('*');
      if (userId != null) {
        entryQuery = entryQuery.eq('user_id', userId);
      }
      final entryRows = await entryQuery;

      // Group entries by store_id
      final Map<String, List<GroceryEntry>> freshEntriesByStore = {};
      for (final e in entryRows) {
        final entry = GroceryEntry.fromJson(e);
        freshEntriesByStore.putIfAbsent(entry.storeId, () => []).add(entry);
      }

      final List<GroceryStore> stores = [];
      for (final s in storeRows) {
        final store = GroceryStore.fromJson(s);
        final storeEntries = freshEntriesByStore[store.id] ?? [];
        
        // Preserve any local entry that is still pending
        final localEntries = cachedEntriesByStore[store.id];
        if (localEntries != null) {
          for (final le in localEntries) {
            if (!storeEntries.any((fe) => fe.id == le.id)) {
              storeEntries.add(le);
            }
          }
        }
        storeEntries.sort((a, b) => b.entryDate.compareTo(a.entryDate));

        cachedEntriesByStore[store.id] = storeEntries;
        _saveEntriesCache(store.id);

        double udhaar = 0.0;
        double chukaya = 0.0;
        for (final entry in storeEntries) {
          if (entry.isUdhaar) udhaar += entry.amount;
          if (entry.isChukaya) chukaya += entry.amount;
        }
        store.totalUdhaar = udhaar;
        store.totalChukaya = chukaya;
        store.entriesCount = storeEntries.length;
        stores.add(store);
      }

      // Preserve any locally cached store that has not synced yet
      for (final local in cachedStores) {
        if (!stores.any((s) => s.id == local.id)) {
          stores.add(local);
        }
      }

      cachedStores = stores;
      dataVersion.value++;
      _saveStoresCache();
      return stores;
    } catch (e) {
      debugPrint('Error fetching grocery stores (falling back to cache): $e');
      return cachedStores;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Compute high-level overview statistics from memory
  static GroceryOverviewStats computeStats(List<GroceryStore> stores) {
    int total = stores.length;
    double udhaar = 0.0;
    double chukaya = 0.0;
    int settled = 0;
    int pending = 0;

    for (final s in stores) {
      udhaar += s.totalUdhaar;
      chukaya += s.totalChukaya;
      if (s.isSettled) {
        settled++;
      } else if (s.pendingBalance > 0) {
        pending++;
      }
    }

    final net = (udhaar - chukaya).clamp(0.0, double.infinity);
    return GroceryOverviewStats(
      totalStores: total,
      totalUdhaar: udhaar,
      totalChukaya: chukaya,
      netPending: net,
      settledStoresCount: settled,
      pendingStoresCount: pending,
    );
  }

  /// Fetch entries for a specific Dukan / Store (Instant 0ms Cache + Background Cloud Refresh)
  static Future<List<GroceryEntry>> fetchEntries(String storeId) async {
    // 1. Immediately return memory cache if present
    final existing = cachedEntriesByStore[storeId];

    // If offline, return cached records immediately without throwing
    if (!ConnectivityService().isOnline.value) {
      if (existing != null) return existing;
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_kCachedEntriesPrefix$storeId');
      if (str != null) {
        final List<dynamic> list = jsonDecode(str);
        final loaded = list.map((e) => GroceryEntry.fromJson(e)).toList();
        cachedEntriesByStore[storeId] = loaded;
        return loaded;
      }
      return [];
    }

    // If online, fetch from cloud
    try {
      final res = await _client
          .from('grocery_entries')
          .select('*')
          .eq('store_id', storeId)
          .order('entry_date', ascending: false);

      final list = (res as List).map((e) => GroceryEntry.fromJson(e)).toList();

      // Preserve local entries that are still pending upload
      if (existing != null) {
        for (final local in existing) {
          if (!list.any((remote) => remote.id == local.id)) {
            list.add(local);
          }
        }
        list.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      }

      cachedEntriesByStore[storeId] = list;
      _saveEntriesCache(storeId);
      return list;
    } catch (e) {
      debugPrint('Network error in fetchEntries, using cached entries: $e');
      return existing ?? [];
    }
  }

  /// Create a new Dukan / Store Account (Works 100% Offline with Auto-Sync)
  static Future<GroceryStore> createStore({
    required String name,
    String category = 'General',
    String? notes,
  }) async {
    final userId = AuthService.currentUserId;
    final storeId = generateUuidV4();
    final newStore = GroceryStore(
      id: storeId,
      userId: userId,
      storeName: name.trim(),
      category: category.trim(),
      notes: notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
      createdAt: DateTime.now(),
    );

    // 1. Instantly save to local cache (0ms)
    cachedStores.insert(0, newStore);
    cachedEntriesByStore[storeId] = [];
    dataVersion.value++;
    await _saveStoresCache();

    // 2. Sync to cloud or queue offline
    if (ConnectivityService().isOnline.value) {
      try {
        await _client.from('grocery_stores').insert(newStore.toJson());
      } catch (e) {
        debugPrint('Cloud insert store failed, queuing offline: $e');
        await _queuePendingStore(newStore);
      }
    } else {
      await _queuePendingStore(newStore);
    }

    return newStore;
  }

  /// Record an Immutable Entry (One-time upload: Works 100% Offline with Auto-Sync)
  static Future<GroceryEntry> addEntry({
    required String storeId,
    required String type, // 'UDHAAR' or 'CHUKAYA'
    required double amount,
    required String itemsDescription,
    DateTime? entryDate,
  }) async {
    final userId = AuthService.currentUserId;
    final date = entryDate ?? DateTime.now();
    final entryId = generateUuidV4();

    final newEntry = GroceryEntry(
      id: entryId,
      storeId: storeId,
      userId: userId,
      type: type,
      amount: amount,
      itemsDescription: itemsDescription.trim(),
      entryDate: date,
      createdAt: DateTime.now(),
    );

    // 1. Instantly update local entries cache (0ms)
    final list = cachedEntriesByStore.putIfAbsent(storeId, () => []);
    list.insert(0, newEntry);
    list.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    await _saveEntriesCache(storeId);

    // 2. Instantly update store summary in local memory
    final storeIndex = cachedStores.indexWhere((s) => s.id == storeId);
    if (storeIndex != -1) {
      final s = cachedStores[storeIndex];
      if (type == 'UDHAAR') {
        s.totalUdhaar += amount;
      } else if (type == 'CHUKAYA') {
        s.totalChukaya += amount;
      }
      s.entriesCount++;
      await _saveStoresCache();
    }

    dataVersion.value++;

    // 3. Push to cloud or queue offline
    if (ConnectivityService().isOnline.value) {
      try {
        await _client.from('grocery_entries').insert(newEntry.toJson());
      } catch (e) {
        debugPrint('Cloud insert entry failed, queuing offline: $e');
        await _queuePendingEntry(newEntry);
      }
    } else {
      await _queuePendingEntry(newEntry);
    }

    return newEntry;
  }

  /// Delete an individual entry (Allowed with confirmation, Works Offline)
  static Future<void> deleteEntry(String entryId, String storeId) async {
    // 1. Instantly remove from local entries cache
    final list = cachedEntriesByStore[storeId];
    if (list != null) {
      final removed = list.firstWhere((e) => e.id == entryId, orElse: () => list.first);
      list.removeWhere((e) => e.id == entryId);
      await _saveEntriesCache(storeId);

      // Re-calculate store totals
      final storeIndex = cachedStores.indexWhere((s) => s.id == storeId);
      if (storeIndex != -1) {
        final s = cachedStores[storeIndex];
        if (removed.isUdhaar) s.totalUdhaar = (s.totalUdhaar - removed.amount).clamp(0.0, double.infinity);
        if (removed.isChukaya) s.totalChukaya = (s.totalChukaya - removed.amount).clamp(0.0, double.infinity);
        s.entriesCount = list.length;
        await _saveStoresCache();
      }
    }

    dataVersion.value++;

    // 2. Delete on cloud or queue
    if (ConnectivityService().isOnline.value) {
      try {
        await _client.from('grocery_entries').delete().eq('id', entryId);
      } catch (_) {
        await _queuePendingDelete('grocery_entries', entryId);
      }
    } else {
      await _queuePendingDelete('grocery_entries', entryId);
    }
  }

  /// Delete a Dukan / Store Account (Works Offline)
  static Future<void> deleteStore(String storeId) async {
    cachedStores.removeWhere((s) => s.id == storeId);
    cachedEntriesByStore.remove(storeId);
    dataVersion.value++;
    await _saveStoresCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kCachedEntriesPrefix$storeId');

    if (ConnectivityService().isOnline.value) {
      try {
        await _client.from('grocery_stores').delete().eq('id', storeId);
      } catch (_) {
        await _queuePendingDelete('grocery_stores', storeId);
      }
    } else {
      await _queuePendingDelete('grocery_stores', storeId);
    }
  }

  // ---------------------------------------------------------------------------
  // Offline Sync Queue Management (Automatic flush on reconnect)
  // ---------------------------------------------------------------------------
  static Future<void> _queuePendingStore(GroceryStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingStores) ?? [];
      list.add(jsonEncode(store.toJson()));
      await prefs.setStringList(_kPendingStores, list);
    } catch (_) {}
  }

  static Future<void> _queuePendingEntry(GroceryEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingEntries) ?? [];
      list.add(jsonEncode(entry.toJson()));
      await prefs.setStringList(_kPendingEntries, list);
    } catch (_) {}
  }

  static Future<void> _queuePendingDelete(String table, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingDeletes) ?? [];
      list.add(jsonEncode({'table': table, 'id': id}));
      await prefs.setStringList(_kPendingDeletes, list);
    } catch (_) {}
  }

  /// Flush pending offline changes when internet connectivity is re-established
  static Future<void> syncPending() async {
    if (!ConnectivityService().isOnline.value) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUid = AuthService.currentUserId;

      // 1. Flush pending stores
      final pendingStores = prefs.getStringList(_kPendingStores) ?? [];
      if (pendingStores.isNotEmpty) {
        final List<String> remaining = [];
        for (final sStr in pendingStores) {
          try {
            final Map<String, dynamic> map = jsonDecode(sStr);
            if (map['user_id'] == null && currentUid != null) {
              map['user_id'] = currentUid;
            }
            await _client.from('grocery_stores').upsert(map);
          } catch (e) {
            remaining.add(sStr);
          }
        }
        await prefs.setStringList(_kPendingStores, remaining);
      }

      // 2. Flush pending entries
      final pendingEntries = prefs.getStringList(_kPendingEntries) ?? [];
      if (pendingEntries.isNotEmpty) {
        final List<String> remaining = [];
        for (final eStr in pendingEntries) {
          try {
            final Map<String, dynamic> map = jsonDecode(eStr);
            if (map['user_id'] == null && currentUid != null) {
              map['user_id'] = currentUid;
            }
            await _client.from('grocery_entries').upsert(map);
          } catch (e) {
            remaining.add(eStr);
          }
        }
        await prefs.setStringList(_kPendingEntries, remaining);
      }

      // 3. Flush pending deletes
      final pendingDeletes = prefs.getStringList(_kPendingDeletes) ?? [];
      if (pendingDeletes.isNotEmpty) {
        final List<String> remaining = [];
        for (final dStr in pendingDeletes) {
          try {
            final map = jsonDecode(dStr);
            final table = map['table'] as String;
            final id = map['id'] as String;
            await _client.from(table).delete().eq('id', id);
          } catch (e) {
            remaining.add(dStr);
          }
        }
        await prefs.setStringList(_kPendingDeletes, remaining);
      }
    } catch (e) {
      debugPrint('Grocery syncPending notice: $e');
    }
  }

  /// Clear in-memory cached state
  static void clearCache() {
    cachedStores.clear();
    cachedEntriesByStore.clear();
    dataVersion.value++;
  }

  /// Completely wipe local Grocery state on sign-out for clean user isolation
  static Future<void> clearAllData() async {
    cachedStores.clear();
    cachedEntriesByStore.clear();
    _initialized = false;
    dataVersion.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedStores);
      await prefs.remove(_kPendingStores);
      await prefs.remove(_kPendingEntries);
      await prefs.remove(_kPendingDeletes);

      final keys = prefs.getKeys().where((k) => k.startsWith(_kCachedEntriesPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
