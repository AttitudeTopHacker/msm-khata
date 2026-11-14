import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

/// Enterprise Multi-Account / Multi-Book Management Service for MsmKhata.
///
/// Features:
/// 1. 100% Data Isolation: Each account (Book 1, Book 2, etc.) maintains strictly separate transactions.
/// 2. Deterministic Startup: Per user requirement, the app ALWAYS defaults to the Primary Account (Book 1) on every launch.
/// 3. Seamless Cloud Synchronization: Automatically syncs all accounts with Supabase so accounts persist across devices and clean-installs.
/// 4. Auto-Discovery Safety Net: Automatically recovers any custom books from existing Supabase transactions if created earlier.
/// 5. 100% Offline Resilience: Offline book creations, renames, and deletions are queued locally and auto-flushed upon reconnection.
class AccountService {
  static const String _kAccountsKey = 'msm_saved_account_books_list';
  static const String _kPendingAccountBooks = 'msm_cache_pending_account_books';
  static const String _kPendingAccountDeletes = 'msm_cache_pending_account_deletes';
  static const String _kDefaultAccountId = 'main';

  // Default Primary Account (Book 1)
  static final AccountBook defaultAccount = AccountBook(
    id: _kDefaultAccountId,
    name: 'Main Account (Book 1)',
    isDefault: true,
    color: '#4F46E5',
    createdAt: DateTime.now().toIso8601String(),
  );

  // Reactive State Notifiers
  static final ValueNotifier<List<AccountBook>> accountsNotifier =
      ValueNotifier<List<AccountBook>>([defaultAccount]);
  static final ValueNotifier<AccountBook> activeAccountNotifier =
      ValueNotifier<AccountBook>(defaultAccount);

  static bool _initialized = false;
  static bool _isSyncingAccounts = false;

  /// Initialize accounts on app startup. Always sets active account to the default first account.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_kAccountsKey);

      List<AccountBook> loaded = [];
      if (savedStr != null && savedStr.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedStr);
          loaded = decoded.map((item) => AccountBook.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Error parsing saved accounts: $e');
        }
      }

      // Ensure default account exists
      if (loaded.isEmpty || !loaded.any((a) => a.id == _kDefaultAccountId)) {
        loaded.insert(0, defaultAccount);
        await _persistAccounts(prefs, loaded);
      }

      accountsNotifier.value = loaded;

      // RULE: Always reset active account to the primary / default account on cold launch
      final primary = loaded.firstWhere(
        (a) => a.isDefault,
        orElse: () => loaded.first,
      );
      activeAccountNotifier.value = primary;

      // Listen for internet reconnect to auto-flush offline accounts
      ConnectivityService().isOnline.addListener(() async {
        if (ConnectivityService().isOnline.value) {
          await syncAccounts();
        }
      });

      // Background cloud sync if user is logged in
      syncAccounts();
    } catch (e) {
      debugPrint('AccountService init error: $e');
    }
  }

  /// Sync all account books with Supabase (Two-way cloud synchronization with offline queue flush)
  static Future<void> syncAccounts() async {
    if (_isSyncingAccounts) return;
    _isSyncingAccounts = true;

    try {
      final userId = AuthService.currentUserId;
      if (userId == null || userId.isEmpty) {
        _isSyncingAccounts = false;
        return;
      }

      final client = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();

      // 0. Flush pending offline deletions FIRST so deleted books never resurrect
      final pendingDeletes = prefs.getStringList(_kPendingAccountDeletes) ?? [];
      if (pendingDeletes.isNotEmpty) {
        final List<String> remainingDeletes = [];
        for (final delId in pendingDeletes) {
          try {
            await client.from('account_books').delete().eq('id', delId);
          } catch (e) {
            remainingDeletes.add(delId);
          }
        }
        await prefs.setStringList(_kPendingAccountDeletes, remainingDeletes);
      }

      // 0.5. Flush pending offline account creations / renames
      final pendingBooks = prefs.getStringList(_kPendingAccountBooks) ?? [];
      if (pendingBooks.isNotEmpty) {
        final List<String> remainingBooks = [];
        for (final bStr in pendingBooks) {
          try {
            final book = AccountBook.fromJson(jsonDecode(bStr));
            await client.from('account_books').upsert({
              'id': book.id,
              'user_id': userId,
              'name': book.name,
              'is_default': book.isDefault,
              'color': book.color,
              'created_at': book.createdAt,
            });
          } catch (e) {
            remainingBooks.add(bStr);
          }
        }
        await prefs.setStringList(_kPendingAccountBooks, remainingBooks);
      }

      // 1. Fetch remote account books from Supabase
      List<AccountBook> remoteBooks = [];
      try {
        final res = await client
            .from('account_books')
            .select()
            .order('created_at', ascending: true);

        final List<dynamic> data = res as List<dynamic>;
        remoteBooks = data.map((json) => AccountBook.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching account_books from Supabase: $e');
      }

      // 2. Auto-Discovery Safety Net:
      // Scan transactions to auto-recover any account_ids that were created previously
      try {
        final txRes = await client
            .from('transactions')
            .select('account_id, account_name')
            .not('account_id', 'is', null);

        final List<dynamic> txRows = txRes as List<dynamic>;
        final Map<String, String> seenInTx = {};
        for (final row in txRows) {
          final aid = row['account_id']?.toString() ?? '';
          final aname = row['account_name']?.toString() ?? '';
          if (aid.isNotEmpty && aid != _kDefaultAccountId) {
            seenInTx[aid] = aname.isNotEmpty ? aname : aid;
          }
        }

        // Filter out any IDs that are currently in pending deletions
        final currentPendingDeletes = prefs.getStringList(_kPendingAccountDeletes) ?? [];
        for (final entry in seenInTx.entries) {
          if (currentPendingDeletes.contains(entry.key)) continue;
          if (!remoteBooks.any((b) => b.id == entry.key)) {
            final recovered = AccountBook(
              id: entry.key,
              name: entry.value,
              isDefault: false,
              color: '#10B981',
              createdAt: DateTime.now().toIso8601String(),
            );
            remoteBooks.add(recovered);
            // Upsert recovered book to Supabase
            try {
              await client.from('account_books').upsert({
                'id': recovered.id,
                'user_id': userId,
                'name': recovered.name,
                'is_default': false,
                'color': recovered.color,
                'created_at': recovered.createdAt,
              });
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Auto-discovery account notice: $e');
      }

      // 3. Ensure Default Book exists in Supabase
      if (!remoteBooks.any((b) => b.id == _kDefaultAccountId)) {
        remoteBooks.insert(0, defaultAccount);
        try {
          await client.from('account_books').upsert({
            'id': defaultAccount.id,
            'user_id': userId,
            'name': defaultAccount.name,
            'is_default': true,
            'color': defaultAccount.color,
            'created_at': defaultAccount.createdAt,
          });
        } catch (_) {}
      }

      // 4. Merge any local books not yet in remote
      final Map<String, AccountBook> merged = {};
      final activeDeletes = prefs.getStringList(_kPendingAccountDeletes) ?? [];
      for (final b in remoteBooks) {
        if (!activeDeletes.contains(b.id)) {
          merged[b.id] = b;
        }
      }
      for (final b in accountsNotifier.value) {
        if (!activeDeletes.contains(b.id) && !merged.containsKey(b.id)) {
          merged[b.id] = b;
          // Upload local book to Supabase
          try {
            await client.from('account_books').upsert({
              'id': b.id,
              'user_id': userId,
              'name': b.name,
              'is_default': b.isDefault,
              'color': b.color,
              'created_at': b.createdAt,
            });
          } catch (_) {}
        }
      }

      final mergedList = merged.values.toList();
      accountsNotifier.value = mergedList;

      // Persist to local disk
      await _persistAccounts(prefs, mergedList);

      // Keep active account valid
      final active = activeAccountNotifier.value;
      if (!merged.containsKey(active.id)) {
        activeAccountNotifier.value = mergedList.firstWhere(
          (a) => a.isDefault,
          orElse: () => mergedList.first,
        );
      }
    } catch (e) {
      debugPrint('Sync accounts error: $e');
    } finally {
      _isSyncingAccounts = false;
    }
  }

  /// Switch active working account / book
  static void switchAccount(String accountId) {
    final match = accountsNotifier.value.where((a) => a.id == accountId);
    if (match.isNotEmpty) {
      activeAccountNotifier.value = match.first;
    }
  }

  /// Create a new isolated account / book (Works 100% Offline with Auto-Sync)
  static Future<AccountBook> createAccount({
    required String name,
    String color = '#10B981',
  }) async {
    final newId = 'book_${DateTime.now().millisecondsSinceEpoch}';
    final newAccount = AccountBook(
      id: newId,
      name: name.trim().isNotEmpty ? name.trim() : 'Book ${accountsNotifier.value.length + 1}',
      isDefault: false,
      color: color,
      createdAt: DateTime.now().toIso8601String(),
    );

    final updated = List<AccountBook>.from(accountsNotifier.value)..add(newAccount);
    accountsNotifier.value = updated;
    activeAccountNotifier.value = newAccount; // switch to newly created book

    // 1. Instant local persistence (0ms UI lag)
    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);

    // 2. Cloud persistence or queue offline
    final userId = AuthService.currentUserId;
    if (ConnectivityService().isOnline.value && userId != null && userId.isNotEmpty) {
      try {
        await Supabase.instance.client.from('account_books').upsert({
          'id': newAccount.id,
          'user_id': userId,
          'name': newAccount.name,
          'is_default': newAccount.isDefault,
          'color': newAccount.color,
          'created_at': newAccount.createdAt,
        });
      } catch (e) {
        debugPrint('Error syncing new account to Supabase, queuing offline: $e');
        await _queuePendingAccount(newAccount);
      }
    } else {
      await _queuePendingAccount(newAccount);
    }

    return newAccount;
  }

  /// Rename an existing account / book (Works 100% Offline with Auto-Sync)
  static Future<void> renameAccount(String accountId, String newName) async {
    if (newName.trim().isEmpty) return;
    final updated = accountsNotifier.value.map((a) {
      if (a.id == accountId) {
        return AccountBook(
          id: a.id,
          name: newName.trim(),
          isDefault: a.isDefault,
          color: a.color,
          createdAt: a.createdAt,
        );
      }
      return a;
    }).toList();

    accountsNotifier.value = updated;
    if (activeAccountNotifier.value.id == accountId) {
      activeAccountNotifier.value = updated.firstWhere((a) => a.id == accountId);
    }

    // 1. Local persistence
    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);

    // 2. Cloud update or queue offline
    final renamedBook = updated.firstWhere((a) => a.id == accountId);
    final userId = AuthService.currentUserId;
    if (ConnectivityService().isOnline.value && userId != null && userId.isNotEmpty) {
      try {
        await Supabase.instance.client.from('account_books').update({
          'name': newName.trim(),
        }).eq('id', accountId);
      } catch (e) {
        debugPrint('Error renaming account in Supabase, queuing offline: $e');
        await _queuePendingAccount(renamedBook);
      }
    } else {
      await _queuePendingAccount(renamedBook);
    }
  }

  /// Delete a book / account (Default account cannot be deleted; Works Offline)
  static Future<bool> deleteAccount(String accountId) async {
    if (accountId == _kDefaultAccountId) return false;

    final updated = accountsNotifier.value.where((a) => a.id != accountId).toList();
    if (updated.isEmpty) return false;

    accountsNotifier.value = updated;
    if (activeAccountNotifier.value.id == accountId) {
      activeAccountNotifier.value = updated.first;
    }

    // 1. Local persistence
    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);

    // 2. Cloud deletion or queue offline
    final userId = AuthService.currentUserId;
    if (ConnectivityService().isOnline.value && userId != null && userId.isNotEmpty) {
      try {
        await Supabase.instance.client.from('account_books').delete().eq('id', accountId);
      } catch (e) {
        debugPrint('Error deleting account in Supabase, queuing offline: $e');
        await _queuePendingDelete(accountId);
      }
    } else {
      await _queuePendingDelete(accountId);
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Offline Queue Helpers
  // ---------------------------------------------------------------------------
  static Future<void> _queuePendingAccount(AccountBook book) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingAccountBooks) ?? [];
      list.removeWhere((s) {
        try {
          final m = jsonDecode(s);
          return m['id'] == book.id;
        } catch (_) {
          return false;
        }
      });
      list.add(jsonEncode(book.toJson()));
      await prefs.setStringList(_kPendingAccountBooks, list);
    } catch (_) {}
  }

  static Future<void> _queuePendingDelete(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCreates = prefs.getStringList(_kPendingAccountBooks) ?? [];
      pendingCreates.removeWhere((s) {
        try {
          final m = jsonDecode(s);
          return m['id'] == accountId;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(_kPendingAccountBooks, pendingCreates);

      final list = prefs.getStringList(_kPendingAccountDeletes) ?? [];
      if (!list.contains(accountId)) {
        list.add(accountId);
        await prefs.setStringList(_kPendingAccountDeletes, list);
      }
    } catch (_) {}
  }

  /// Reset to default primary account on sign out & purge queues
  static Future<void> resetToDefault() async {
    accountsNotifier.value = [defaultAccount];
    activeAccountNotifier.value = defaultAccount;
    _initialized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccountsKey);
      await prefs.remove(_kPendingAccountBooks);
      await prefs.remove(_kPendingAccountDeletes);
    } catch (_) {}
  }

  static Future<void> _persistAccounts(
    SharedPreferences prefs,
    List<AccountBook> list,
  ) async {
    try {
      final jsonStr = jsonEncode(list.map((a) => a.toJson()).toList());
      await prefs.setString(_kAccountsKey, jsonStr);
    } catch (e) {
      debugPrint('Error persisting accounts list: $e');
    }
  }
}
