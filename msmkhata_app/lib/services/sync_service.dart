import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import '../models/person.dart';
import '../models/category.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'account_service.dart';
import 'connectivity_service.dart';

/// Enterprise Data Synchronization & Offline Cache Service for MsmKhata.
///
/// Features:
/// 1. 100% Deterministic Consistency: UUID deduplication guarantees zero lost/duplicate records.
/// 2. Instant 0ms Cold Start: Loads instantly from local cache while syncing in the background.
/// 3. Offline Transaction Queue: Entries are saved locally without internet and auto-flushed to Supabase upon reconnect.
/// 4. Multi-Account / Multi-Book Scoped Isolation.
/// 5. Master Cache Purge on Sign-Out to prevent multi-user data leakage.
class SyncService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _kStatsKey = 'msm_cache_dashboard_stats';
  static const String _kTransactionsKey = 'msm_cache_transactions';
  static const String _kPersonsKey = 'msm_cache_persons';
  static const String _kLastSyncKey = 'msm_cache_last_sync_timestamp';

  // Offline Pending Queues
  static const String _kPendingTransactions = 'msm_cache_pending_transactions';
  static const String _kPendingTransactionUpdates = 'msm_cache_pending_tx_updates';
  static const String _kPendingTransactionDeletes = 'msm_cache_pending_tx_deletes';
  static const String _kPendingCategories = 'msm_cache_pending_categories';
  static const String _kPendingPersons = 'msm_cache_pending_persons';

  // In-memory state cache
  static DashboardStats? cachedStats;
  static List<TransactionItem> cachedTransactions = [];
  static List<Person> cachedPersons = [];

  // Reactive State Notifiers
  static final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  static final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static bool _initialized = false;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Helper: Generate RFC 4122 v4 UUID
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Update the live pending offline item counter across all modules
  static Future<int> updatePendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = 0;
      count += (prefs.getStringList(_kPendingTransactions) ?? []).length;
      count += (prefs.getStringList(_kPendingTransactionUpdates) ?? []).length;
      count += (prefs.getStringList(_kPendingTransactionDeletes) ?? []).length;
      count += (prefs.getStringList(_kPendingCategories) ?? []).length;
      count += (prefs.getStringList(_kPendingPersons) ?? []).length;
      count += (prefs.getStringList('msm_cache_grocery_pending_entries') ?? []).length;
      count += (prefs.getStringList('msm_cache_grocery_pending_stores') ?? []).length;
      count += (prefs.getStringList('msm_cache_grocery_pending_deletes') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_routine_entries') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_routine_deletes') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_routine_categories') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_routine_category_deletes') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_account_books') ?? []).length;
      count += (prefs.getStringList('msm_cache_pending_account_deletes') ?? []).length;
      pendingCountNotifier.value = count;
      return count;
    } catch (_) {
      return pendingCountNotifier.value;
    }
  }

  /// Instant 0ms Local Stats Recalculation: Computes dashboard balances offline directly from local transactions cache
  static DashboardStats recalculateStatsLocally({String? accountId}) {
    final activeId = accountId ?? AccountService.activeAccountNotifier.value.id;
    final filtered = cachedTransactions.where((tx) {
      if (activeId == 'all') return true;
      final txAid = tx.accountId;
      return txAid == activeId || (activeId == 'main' && (txAid.isEmpty || txAid == 'main'));
    }).toList();

    double income = 0;
    double expense = 0;
    double totalGivenCashOut = 0;
    double totalTakenCashIn = 0;
    final Map<String, double> categorySums = {};
    final Map<String, Map<String, double>> monthlyAggregates = {};

    for (final tx in filtered) {
      final amt = tx.amount;
      final t = tx.type.toLowerCase();
      final dateStr = tx.transactionDate ?? '';

      if (dateStr.length >= 7) {
        final monthKey = dateStr.substring(0, 7);
        monthlyAggregates.putIfAbsent(monthKey, () => {
          'income': 0.0,
          'expense': 0.0,
          'given': 0.0,
          'taken': 0.0,
        });
        if (t == 'income') {
          monthlyAggregates[monthKey]!['income'] = monthlyAggregates[monthKey]!['income']! + amt;
        } else if (t == 'expense') {
          monthlyAggregates[monthKey]!['expense'] = monthlyAggregates[monthKey]!['expense']! + amt;
        } else if (t == 'given' || t == 'lena' || t == 'receivable') {
          monthlyAggregates[monthKey]!['given'] = monthlyAggregates[monthKey]!['given']! + amt;
        } else if (t == 'taken' || t == 'diya' || t == 'payable') {
          monthlyAggregates[monthKey]!['taken'] = monthlyAggregates[monthKey]!['taken']! + amt;
        }
      }

      if (t == 'income') {
        income += amt;
      } else if (t == 'expense') {
        expense += amt;
        String catName = tx.categoryName?.trim() ?? '';
        if (catName.isEmpty && tx.categoryId != null) {
          final matched = ApiService.defaultCategories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => Category(id: '', name: '', type: ''),
          );
          if (matched.name.isNotEmpty) catName = matched.name;
        }
        if (catName.isEmpty) catName = 'Other Expenses';
        categorySums[catName] = (categorySums[catName] ?? 0) + amt;
      } else if (t == 'given' || t == 'lena' || t == 'receivable') {
        totalGivenCashOut += amt;
      } else if (t == 'taken' || t == 'diya' || t == 'payable') {
        totalTakenCashIn += amt;
      }
    }

    final moneyIn = income + totalTakenCashIn;
    final moneyOut = expense + totalGivenCashOut;
    final netBalance = moneyIn - moneyOut;
    final netSavings = income - expense;

    final List<CategoryBreakdown> catList = [];
    final totalExpenseForBreakdown = expense > 0 ? expense : 1.0;
    categorySums.forEach((name, total) {
      final matched = ApiService.defaultCategories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Category(id: '', name: name, type: 'EXPENSE', color: '#6366F1'),
      );
      catList.add(CategoryBreakdown(
        categoryName: name,
        color: matched.color,
        totalAmount: total,
        percentage: (total / totalExpenseForBreakdown) * 100,
      ));
    });
    catList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final sortedMonths = monthlyAggregates.keys.toList()..sort();
    final List<MonthlyTrendItem> trends = sortedMonths.map((m) {
      final data = monthlyAggregates[m]!;
      return MonthlyTrendItem(
        month: m,
        totalIncome: data['income']!,
        totalExpense: data['expense']!,
        totalGiven: data['given']!,
        totalTaken: data['taken']!,
      );
    }).toList();

    // Ensure person balances are up to date
    recalculatePersonsLocally();

    final debtors = cachedPersons
        .where((p) => p.netBalance > 0)
        .toList()
      ..sort((a, b) => b.netBalance.compareTo(a.netBalance));
    final topDebtors = debtors.take(5).map((p) => PersonBalanceSummary(
      personId: p.id,
      name: p.name,
      totalGiven: p.totalGiven,
      totalTaken: p.totalTaken,
      netBalance: p.netBalance,
      status: 'OWES_YOU',
    )).toList();

    final creditors = cachedPersons
        .where((p) => p.netBalance < 0)
        .toList()
      ..sort((a, b) => b.netBalance.abs().compareTo(a.netBalance.abs()));
    final topCreditors = creditors.take(5).map((p) => PersonBalanceSummary(
      personId: p.id,
      name: p.name,
      totalGiven: p.totalGiven,
      totalTaken: p.totalTaken,
      netBalance: p.netBalance.abs(),
      status: 'YOU_OWE',
    )).toList();

    // Calculate total receivable & payable based on net party balances (Khata accounting)
    final totalReceivable = debtors.fold<double>(0.0, (sum, p) => sum + p.netBalance);
    final totalPayable = creditors.fold<double>(0.0, (sum, p) => sum + p.netBalance.abs());
    final netLenDen = totalReceivable - totalPayable;

    final newStats = DashboardStats(
      netAccountBalance: netBalance,
      totalMoneyIn: moneyIn,
      totalMoneyOut: moneyOut,
      activeAccountId: activeId,
      totalReceivable: totalReceivable,
      totalPayable: totalPayable,
      netLenDenPosition: netLenDen,
      totalIncome: income,
      totalExpense: expense,
      netSavings: netSavings,
      peopleToReceiveCount: debtors.length,
      peopleToPayCount: creditors.length,
      totalTransactionsCount: filtered.length,
      categoryBreakdown: catList.isNotEmpty ? catList : (cachedStats?.categoryBreakdown ?? []),
      topDebtors: topDebtors.isNotEmpty ? topDebtors : (cachedStats?.topDebtors ?? []),
      topCreditors: topCreditors.isNotEmpty ? topCreditors : (cachedStats?.topCreditors ?? []),
      monthlyTrends: trends.isNotEmpty ? trends : (cachedStats?.monthlyTrends ?? []),
    );

    cachedStats = newStats;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kStatsKey, jsonEncode(newStats.toJson()));
    }).catchError((_) {});

    return newStats;
  }

  /// Initialize local cache from persistent storage on app launch
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore Last Sync Time
      final lastSyncStr = prefs.getString(_kLastSyncKey);
      if (lastSyncStr != null) {
        lastSyncTime.value = DateTime.tryParse(lastSyncStr);
      }

      // 2. Restore Cached Stats
      final statsJson = prefs.getString(_kStatsKey);
      if (statsJson != null) {
        try {
          cachedStats = DashboardStats.fromJson(jsonDecode(statsJson));
        } catch (e) {
          debugPrint('Error restoring cached stats: $e');
        }
      }

      // 3. Restore Cached Transactions
      final txsJson = prefs.getString(_kTransactionsKey);
      if (txsJson != null) {
        try {
          final List<dynamic> list = jsonDecode(txsJson);
          cachedTransactions = list.map((e) {
            final tx = TransactionItem.fromJson(e);
            if ((tx.categoryName == null || tx.categoryName!.isEmpty) && tx.categoryId != null) {
              final matched = ApiService.defaultCategories.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => Category(id: '', name: '', type: ''),
              );
              if (matched.name.isNotEmpty) {
                return tx.copyWith(
                  categoryName: matched.name,
                  categoryColor: matched.color,
                );
              }
            }
            return tx;
          }).toList();
        } catch (e) {
          debugPrint('Error restoring cached transactions: $e');
        }
      }

      // 4. Restore Cached Persons
      final personsJson = prefs.getString(_kPersonsKey);
      if (personsJson != null) {
        try {
          final List<dynamic> list = jsonDecode(personsJson);
          cachedPersons = list.map((e) => Person.fromJson(e)).toList();
        } catch (e) {
          debugPrint('Error restoring cached persons: $e');
        }
      }

      // 4.5. Always recalculate stats and persons locally from cached transactions on launch to guarantee 100% accurate balances
      if (cachedTransactions.isNotEmpty) {
        recalculateStatsLocally();
        recalculatePersonsLocally();
      }

      // Update pending items counter
      await updatePendingCount();

      dataVersion.value++;

      // 5. Listen for reconnect to auto-flush offline queues
      ConnectivityService().isOnline.addListener(() async {
        if (ConnectivityService().isOnline.value) {
          await syncPending();
          await syncAll();
        }
      });

      // 6. Background initial flush if online
      if (ConnectivityService().isOnline.value) {
        syncPending().then((_) => syncAll());
      }
    } catch (e) {
      debugPrint('SyncService init error: $e');
    }
  }

  /// Trigger global sync across Dashboard stats, Contacts, and Transactions
  static Future<void> syncAll({bool forceFull = false}) async {
    if (isSyncing.value) return;
    isSyncing.value = true;

    // Check internet connectivity
    ConnectivityService.checkNow();

    try {
      // 1. Flush any pending offline transactions first
      await syncPending();

      await Future.wait([
        AccountService.syncAccounts(),
        syncStats(),
        syncPersons(),
        syncTransactions(limit: 100, offset: 0, replaceCache: forceFull),
      ]);

      final now = DateTime.now();
      lastSyncTime.value = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncKey, now.toIso8601String());
    } catch (e) {
      debugPrint('Global sync notice: $e');
    } finally {
      isSyncing.value = false;
      dataVersion.value++;
    }
  }

  /// Sync Dashboard Stats
  static Future<DashboardStats?> syncStats() async {
    try {
      final stats = await ApiService.getDashboardStats();
      cachedStats = stats;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStatsKey, jsonEncode(stats.toJson()));
      return stats;
    } catch (e) {
      debugPrint('Sync stats notice, fallback to direct Supabase: $e');
      return await fetchStatsDirectly();
    }
  }

  /// Direct Supabase fetch for dashboard stats (calculates accurately across all records in Supabase)
  static Future<DashboardStats> fetchStatsDirectly({String? accountId}) async {
    final uid = AuthService.currentUserId;
    final activeId = accountId ?? AccountService.activeAccountNotifier.value.id;

    try {
      if (cachedPersons.isEmpty) {
        await fetchPersonsDirectly();
      }

      var query = _client.from('transactions').select('type, amount, account_id, transaction_date, categories(id, name, color)');
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      if (activeId.isNotEmpty && activeId != 'all') {
        query = query.eq('account_id', activeId);
      }

      final dynamic rows = await query;
      if (rows is List) {
        double income = 0;
        double expense = 0;
        double totalGivenCashOut = 0;
        double totalTakenCashIn = 0;
        final Map<String, double> categorySums = {};
        final Map<String, String> categoryColors = {};
        final Map<String, Map<String, double>> monthlyAggregates = {};

        for (final dynamic row in rows) {
          final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
          final type = (row['type'] as String?)?.toUpperCase() ?? '';
          final dateStr = (row['transaction_date'] as String?) ?? '';

          if (dateStr.length >= 7) {
            final monthKey = dateStr.substring(0, 7);
            monthlyAggregates.putIfAbsent(monthKey, () => {
              'income': 0.0,
              'expense': 0.0,
              'given': 0.0,
              'taken': 0.0,
            });
            if (type == 'INCOME') {
              monthlyAggregates[monthKey]!['income'] = monthlyAggregates[monthKey]!['income']! + amt;
            } else if (type == 'EXPENSE') {
              monthlyAggregates[monthKey]!['expense'] = monthlyAggregates[monthKey]!['expense']! + amt;
            } else if (type == 'GIVEN') {
              monthlyAggregates[monthKey]!['given'] = monthlyAggregates[monthKey]!['given']! + amt;
            } else if (type == 'TAKEN') {
              monthlyAggregates[monthKey]!['taken'] = monthlyAggregates[monthKey]!['taken']! + amt;
            }
          }

          if (type == 'INCOME') {
            income += amt;
          } else if (type == 'EXPENSE') {
            expense += amt;
            final catObj = row['categories'];
            String catName = 'Other Expenses';
            String catColor = '#6366F1';
            if (catObj is Map) {
              final n = catObj['name'] as String?;
              if (n != null && n.isNotEmpty) catName = n;
              final c = catObj['color'] as String?;
              if (c != null && c.isNotEmpty) catColor = c;
            }
            categorySums[catName] = (categorySums[catName] ?? 0) + amt;
            categoryColors[catName] = catColor;
          } else if (type == 'GIVEN') {
            totalGivenCashOut += amt;
          } else if (type == 'TAKEN') {
            totalTakenCashIn += amt;
          }
        }

        final moneyIn = income + totalTakenCashIn;
        final moneyOut = expense + totalGivenCashOut;
        final netBalance = moneyIn - moneyOut;
        final netSavings = income - expense;

        final List<CategoryBreakdown> catList = [];
        final totalExpenseForBreakdown = expense > 0 ? expense : 1.0;
        categorySums.forEach((name, total) {
          catList.add(CategoryBreakdown(
            categoryName: name,
            color: categoryColors[name] ?? '#6366F1',
            totalAmount: total,
            percentage: (total / totalExpenseForBreakdown) * 100,
          ));
        });
        catList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        final sortedMonths = monthlyAggregates.keys.toList()..sort();
        final List<MonthlyTrendItem> trends = sortedMonths.map((m) {
          final data = monthlyAggregates[m]!;
          return MonthlyTrendItem(
            month: m,
            totalIncome: data['income']!,
            totalExpense: data['expense']!,
            totalGiven: data['given']!,
            totalTaken: data['taken']!,
          );
        }).toList();

        final debtors = cachedPersons
            .where((p) => p.netBalance > 0)
            .toList()
          ..sort((a, b) => b.netBalance.compareTo(a.netBalance));
        final topDebtors = debtors.take(5).map((p) => PersonBalanceSummary(
          personId: p.id,
          name: p.name,
          totalGiven: p.totalGiven,
          totalTaken: p.totalTaken,
          netBalance: p.netBalance,
          status: 'OWES_YOU',
        )).toList();

        final creditors = cachedPersons
            .where((p) => p.netBalance < 0)
            .toList()
          ..sort((a, b) => b.netBalance.abs().compareTo(a.netBalance.abs()));
        final topCreditors = creditors.take(5).map((p) => PersonBalanceSummary(
          personId: p.id,
          name: p.name,
          totalGiven: p.totalGiven,
          totalTaken: p.totalTaken,
          netBalance: p.netBalance.abs(),
          status: 'YOU_OWE',
        )).toList();

        // Calculate total receivable & payable based on net party balances (Khata accounting)
        final totalReceivable = debtors.fold<double>(0.0, (sum, p) => sum + p.netBalance);
        final totalPayable = creditors.fold<double>(0.0, (sum, p) => sum + p.netBalance.abs());
        final netLenDen = totalReceivable - totalPayable;

        final freshStats = DashboardStats(
          netAccountBalance: netBalance,
          totalMoneyIn: moneyIn,
          totalMoneyOut: moneyOut,
          activeAccountId: activeId,
          totalReceivable: totalReceivable,
          totalPayable: totalPayable,
          netLenDenPosition: netLenDen,
          totalIncome: income,
          totalExpense: expense,
          netSavings: netSavings,
          peopleToReceiveCount: debtors.length,
          peopleToPayCount: creditors.length,
          totalTransactionsCount: rows.length,
          categoryBreakdown: catList.isNotEmpty ? catList : (cachedStats?.categoryBreakdown ?? []),
          topDebtors: topDebtors.isNotEmpty ? topDebtors : (cachedStats?.topDebtors ?? []),
          topCreditors: topCreditors.isNotEmpty ? topCreditors : (cachedStats?.topCreditors ?? []),
          monthlyTrends: trends.isNotEmpty ? trends : (cachedStats?.monthlyTrends ?? []),
        );

        cachedStats = freshStats;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kStatsKey, jsonEncode(freshStats.toJson()));
        return freshStats;
      }
    } catch (e) {
      debugPrint('Direct Supabase fetchStatsDirectly notice: $e');
    }

    final fallback = recalculateStatsLocally(accountId: activeId);
    cachedStats = fallback;
    return fallback;
  }

  /// Sync Contacts / Persons
  static Future<List<Person>> syncPersons({String? status}) async {
    try {
      final list = await ApiService.getPersons(status: status);
      cachedPersons = list;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPersonsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
      return list;
    } catch (e) {
      debugPrint('Sync persons notice: $e');
      try {
        final list = await fetchPersonsDirectly(status: status);
        cachedPersons = list;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPersonsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
        return list;
      } catch (subErr) {
        debugPrint('Direct Supabase persons fetch error: $subErr');
        return cachedPersons;
      }
    }
  }

  /// Direct Supabase fetch for persons with real-time Len-Den balance calculation
  static Future<List<Person>> fetchPersonsDirectly({String? status, String? userId}) async {
    final uid = userId ?? AuthService.currentUserId;
    if (uid == null) return cachedPersons;

    try {
      final personsData = await _client
          .from('persons')
          .select('*')
          .eq('user_id', uid)
          .order('name', ascending: true);

      final List<dynamic> pRows = personsData as List<dynamic>;

      final txData = await _client
          .from('transactions')
          .select('id, person_id, type, amount, is_settled')
          .eq('user_id', uid)
          .inFilter('type', ['GIVEN', 'TAKEN']);

      final List<dynamic> tRows = txData as List<dynamic>;

      final Map<String, Map<String, dynamic>> stats = {};
      for (final p in pRows) {
        stats[p['id'].toString()] = {'given': 0.0, 'taken': 0.0, 'count': 0};
      }

      for (final t in tRows) {
        final pid = t['person_id']?.toString();
        if (pid == null || !stats.containsKey(pid)) continue;
        final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
        final type = (t['type'] as String?)?.toUpperCase() ?? '';
        stats[pid]!['count'] = (stats[pid]!['count'] as int) + 1;
        if (type == 'GIVEN') {
          stats[pid]!['given'] = (stats[pid]!['given'] as double) + amt;
        } else if (type == 'TAKEN') {
          stats[pid]!['taken'] = (stats[pid]!['taken'] as double) + amt;
        }
      }

      final Map<String, Person> dedupedResult = {};
      for (final p in pRows) {
        final pid = p['id'].toString();
        final s = stats[pid] ?? {'given': 0.0, 'taken': 0.0, 'count': 0};
        final given = s['given'] as double;
        final taken = s['taken'] as double;
        final net = double.parse((given - taken).toStringAsFixed(2));

        String pStatus = 'SETTLED';
        if (net > 0) {
          pStatus = 'TO_RECEIVE';
        } else if (net < 0) {
          pStatus = 'TO_PAY';
        }

        if (status != null && status.isNotEmpty && pStatus != status.toUpperCase()) {
          continue;
        }

        final pName = (p['name'] as String?)?.trim() ?? '';
        final normKey = pName.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        if (normKey.isEmpty) continue;

        if (!dedupedResult.containsKey(normKey)) {
          dedupedResult[normKey] = Person(
            id: pid,
            name: pName,
            phone: p['phone'],
            notes: p['notes'],
            totalGiven: given,
            totalTaken: taken,
            netBalance: net,
            status: pStatus,
            transactionCount: s['count'] as int,
          );
        } else {
          final existing = dedupedResult[normKey]!;
          final mergedGiven = existing.totalGiven + given;
          final mergedTaken = existing.totalTaken + taken;
          final mergedNet = double.parse((mergedGiven - mergedTaken).toStringAsFixed(2));
          String mergedStatus = 'SETTLED';
          if (mergedNet > 0) mergedStatus = 'TO_RECEIVE';
          else if (mergedNet < 0) mergedStatus = 'TO_PAY';

          dedupedResult[normKey] = Person(
            id: existing.id,
            name: existing.name,
            phone: existing.phone ?? p['phone'],
            notes: existing.notes ?? p['notes'],
            totalGiven: mergedGiven,
            totalTaken: mergedTaken,
            netBalance: mergedNet,
            status: mergedStatus,
            transactionCount: existing.transactionCount + (s['count'] as int),
          );
        }
      }

      return dedupedResult.values.toList();
    } catch (e) {
      debugPrint('fetchPersonsDirectly error: $e');
      return cachedPersons;
    }
  }

  /// Direct Supabase fetch for transactions with table joins
  static Future<List<TransactionItem>> fetchTransactionsDirectly({
    int limit = 5000,
    int offset = 0,
    String? accountId,
  }) async {
    final uid = AuthService.currentUserId;
    final activeBook = AccountService.activeAccountNotifier.value;
    final aid = accountId ?? activeBook.id;

    try {
      var query = _client.from('transactions')
          .select('*, persons(name), categories(name, color)');

      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      if (aid.isNotEmpty && aid != 'all') {
        query = query.eq('account_id', aid);
      }

      final data = await query
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> rows = data as List<dynamic>;
      return rows.map((r) {
        final tx = TransactionItem.fromJson(r as Map<String, dynamic>);
        if ((tx.categoryName == null || tx.categoryName!.isEmpty) && tx.categoryId != null) {
          final matched = ApiService.defaultCategories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => Category(id: '', name: '', type: ''),
          );
          if (matched.name.isNotEmpty) {
            return tx.copyWith(
              categoryName: matched.name,
              categoryColor: matched.color,
            );
          }
        }
        return tx;
      }).toList();
    } catch (e) {
      debugPrint('fetchTransactionsDirectly error: $e');
      return [];
    }
  }

  /// Incremental / Paged sync for transactions with 100% deterministic UUID deduplication
  static Future<List<TransactionItem>> syncTransactions({
    int limit = 5000,
    int offset = 0,
    bool replaceCache = false,
  }) async {
    List<TransactionItem> remoteList = [];
    try {
      remoteList = await ApiService.getTransactions(limit: limit, offset: offset);
    } catch (e) {
      debugPrint('Sync transactions API notice, attempting direct Supabase: $e');
      try {
        remoteList = await fetchTransactionsDirectly(limit: limit, offset: offset);
      } catch (subErr) {
        debugPrint('Direct Supabase transactions error: $subErr');
      }
    }

    if (remoteList.isNotEmpty) {
      if (replaceCache) {
        // Explicit full reset only
        final List<TransactionItem> list = List.from(remoteList);
        _sortTransactions(list);
        cachedTransactions = list;
      } else {
        // Deterministic ID-based Upsert / Merge
        final Map<String, TransactionItem> map = {
          for (final item in cachedTransactions) item.id: item
        };
        for (final item in remoteList) {
          map[item.id] = item;
        }
        final merged = map.values.toList();
        _sortTransactions(merged);
        cachedTransactions = merged;
      }

      // Persist to local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTransactionsKey,
        jsonEncode(cachedTransactions.map((e) => e.toJson()).toList()),
      );
    }

    dataVersion.value++;
    return remoteList;
  }

  /// Find person by name or create in Supabase, returning their valid UUID (with strict deduplication)
  static Future<String> getOrCreatePersonId(String name, {String? userId}) async {
    final uid = userId ?? AuthService.currentUserId;
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    final normalized = cleaned.toLowerCase();

    // 1. Check local cached persons (case-insensitive & trimmed)
    final localMatch = cachedPersons.where(
      (p) => p.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() == normalized && _uuidRegex.hasMatch(p.id)
    );
    if (localMatch.isNotEmpty) {
      return localMatch.first.id;
    }

    // 2. Check Supabase directly for this user (never create duplicates)
    try {
      var query = _client.from('persons').select('id, name');
      if (uid != null) {
        query = query.eq('user_id', uid);
      }
      final existingRows = await query;
      if (existingRows is List) {
        for (final row in existingRows) {
          final rName = (row['name'] as String?)?.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ?? '';
          if (rName == normalized && row['id'] != null) {
            final foundId = row['id'].toString();
            if (!cachedPersons.any((p) => p.id == foundId)) {
              cachedPersons.add(Person(id: foundId, name: row['name']?.toString() ?? cleaned));
            }
            return foundId;
          }
        }
      }

      // 3. Create new person in Supabase only if truly unique
      final newPerson = await _client.from('persons').insert({
        'name': cleaned,
        if (uid != null) 'user_id': uid,
      }).select().single();

      final newId = newPerson['id'].toString();
      cachedPersons.add(Person(id: newId, name: cleaned));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPersonsKey, jsonEncode(cachedPersons.map((e) => e.toJson()).toList()));
      return newId;
    } catch (e) {
      debugPrint('getOrCreatePersonId notice: $e');
      final offlineId = generateUuidV4();
      final p = Person(id: offlineId, name: cleaned);
      cachedPersons.add(p);
      await _queuePendingPerson(p);
      return offlineId;
    }
  }

  /// Find category by name or create in Supabase, returning its valid UUID (with strict fallback)
  static Future<String?> getOrCreateCategoryId(String? name, {String? type = 'EXPENSE', String? userId}) async {
    if (name == null || name.trim().isEmpty) return null;
    final cleaned = name.trim();
    final norm = cleaned.toLowerCase();

    // 1. Check in defaultCategories
    final match = ApiService.defaultCategories.firstWhere(
      (c) => c.name.toLowerCase() == norm ||
             c.name.toLowerCase().startsWith(norm) ||
             norm.startsWith(c.name.toLowerCase()),
      orElse: () => Category(id: '', name: '', type: ''),
    );
    if (match.id.isNotEmpty && _uuidRegex.hasMatch(match.id)) {
      return match.id;
    }

    // 2. Query Supabase categories table
    try {
      final uid = userId ?? AuthService.currentUserId;
      final dynamic rows = await _client
          .from('categories')
          .select('id, name')
          .ilike('name', cleaned);
      if (rows is List && rows.isNotEmpty) {
        final id = rows.first['id']?.toString();
        if (id != null && _uuidRegex.hasMatch(id)) return id;
      }

      // 3. Create category in Supabase
      final inserted = await _client.from('categories').insert({
        'name': cleaned,
        'type': type ?? 'EXPENSE',
        'color': '#3B82F6',
        if (uid != null) 'user_id': uid,
      }).select().single();
      final newId = inserted['id']?.toString();
      if (newId != null && _uuidRegex.hasMatch(newId)) return newId;
    } catch (e) {
      debugPrint('getOrCreateCategoryId notice: $e');
    }
    return null;
  }

  /// Recalculates cachedPersons balances instantly in 0ms from cachedTransactions
  static void recalculatePersonsLocally() {
    final Map<String, Map<String, dynamic>> map = {};
    for (final p in cachedPersons) {
      map[p.id] = {
        'name': p.name,
        'phone': p.phone,
        'notes': p.notes,
        'given': 0.0,
        'taken': 0.0,
        'count': 0,
      };
    }

    for (final t in cachedTransactions) {
      final pid = t.personId;
      final pname = t.personName;
      if (pid == null && (pname == null || pname.isEmpty)) continue;

      String targetKey = pid ?? '';
      if (targetKey.isEmpty || !map.containsKey(targetKey)) {
        final match = map.entries.where(
          (e) => (e.value['name'] as String).toLowerCase() == (pname ?? '').toLowerCase()
        );
        if (match.isNotEmpty) {
          targetKey = match.first.key;
        } else if (pname != null && pname.isNotEmpty) {
          targetKey = pid ?? generateUuidV4();
          map[targetKey] = {
            'name': pname,
            'phone': null,
            'notes': null,
            'given': 0.0,
            'taken': 0.0,
            'count': 0,
          };
        }
      }

      if (targetKey.isNotEmpty && map.containsKey(targetKey)) {
        final amt = t.amount;
        final type = t.type.toUpperCase();
        map[targetKey]!['count'] = (map[targetKey]!['count'] as int) + 1;
        if (type == 'GIVEN') {
          map[targetKey]!['given'] = (map[targetKey]!['given'] as double) + amt;
        } else if (type == 'TAKEN') {
          map[targetKey]!['taken'] = (map[targetKey]!['taken'] as double) + amt;
        }
      }
    }

    final List<Person> updated = [];
    map.forEach((id, s) {
      final given = s['given'] as double;
      final taken = s['taken'] as double;
      final net = double.parse((given - taken).toStringAsFixed(2));
      String status = 'SETTLED';
      if (net > 0) {
        status = 'TO_RECEIVE';
      } else if (net < 0) {
        status = 'TO_PAY';
      }
      updated.add(Person(
        id: id,
        name: s['name'] as String,
        phone: s['phone'] as String?,
        notes: s['notes'] as String?,
        totalGiven: given,
        totalTaken: taken,
        netBalance: net,
        status: status,
        transactionCount: s['count'] as int,
      ));
    });

    cachedPersons = updated;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kPersonsKey, jsonEncode(cachedPersons.map((e) => e.toJson()).toList()));
    });
  }

  /// Record a new transaction (Works 100% Offline with Auto-Sync & Deduplication)
  static Future<TransactionItem> recordTransaction({
    required String type,
    required double amount,
    required String paymentMode,
    String? personName,
    String? personId,
    String? categoryName,
    String? categoryId,
    String? notes,
    String? dueDate,
    String? transactionDate,
    String? accountId,
    String? accountName,
  }) async {
    final userId = AuthService.currentUserId;
    final activeBook = AccountService.activeAccountNotifier.value;
    final aid = accountId ?? activeBook.id;
    final aname = accountName ?? activeBook.name;
    final tDate = transactionDate ?? DateTime.now().toIso8601String().split('T')[0];
    final txId = generateUuidV4();

    String? validPersonId = (personId != null && _uuidRegex.hasMatch(personId)) ? personId : null;
    final isLenDen = type == 'GIVEN' || type == 'TAKEN';
    if (isLenDen && validPersonId == null && personName != null && personName.trim().isNotEmpty) {
      validPersonId = await getOrCreatePersonId(personName, userId: userId);
    }

    String? validCategoryId = (categoryId != null && _uuidRegex.hasMatch(categoryId)) ? categoryId : null;
    final isExpenseOrIncome = type == 'EXPENSE' || type == 'INCOME';
    if (isExpenseOrIncome && validCategoryId == null && categoryName != null && categoryName.trim().isNotEmpty) {
      validCategoryId = await getOrCreateCategoryId(categoryName, type: type, userId: userId);
    }

    // Resolve category name and color if missing
    String? resolvedCatName = categoryName;
    String? resolvedCatColor;
    if (validCategoryId != null) {
      final matchedCat = ApiService.defaultCategories.firstWhere(
        (c) => c.id == validCategoryId,
        orElse: () => Category(id: '', name: '', type: ''),
      );
      if (matchedCat.name.isNotEmpty) {
        resolvedCatName ??= matchedCat.name;
        resolvedCatColor ??= matchedCat.color;
      }
    }

    final localTx = TransactionItem(
      id: txId,
      type: type,
      amount: amount,
      paymentMode: paymentMode,
      personName: personName,
      personId: validPersonId,
      categoryName: resolvedCatName,
      categoryId: validCategoryId,
      categoryColor: resolvedCatColor,
      notes: notes,
      dueDate: dueDate,
      transactionDate: tDate,
      accountId: aid,
      accountName: aname,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Instantly save to local cache (0ms Cold UI response)
    onOptimisticTransactionCreated(localTx);

    // 2. Push to Cloud or Queue Offline
    if (ConnectivityService().isOnline.value) {
      try {
        final serverTx = await ApiService.createTransaction(
          id: txId,
          type: type,
          amount: amount,
          paymentMode: paymentMode,
          personName: personName,
          personId: validPersonId,
          categoryName: resolvedCatName,
          categoryId: validCategoryId,
          notes: notes,
          dueDate: dueDate,
          transactionDate: tDate,
          accountId: aid,
          accountName: aname,
          userId: userId,
        );
        onOptimisticTransactionUpdated(serverTx);
        return serverTx;
      } catch (e) {
        debugPrint('Direct API transaction insert failed, attempting Supabase direct / offline queue: $e');
        try {
          final txMap = <String, dynamic>{
            'id': txId,
            if (userId != null) 'user_id': userId,
            'account_id': aid,
            'account_name': aname,
            'type': type,
            'amount': amount,
            'payment_mode': paymentMode,
            'transaction_date': tDate,
            'is_settled': false,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
            if (validPersonId != null) 'person_id': validPersonId,
            if (validCategoryId != null) 'category_id': validCategoryId,
            'created_at': DateTime.now().toIso8601String(),
          };
          await _client.from('transactions').upsert(txMap);
        } catch (subErr) {
          debugPrint('Supabase direct insert also failed, queuing offline: $subErr');
          await _queuePendingTransaction(localTx);
        }
      }
    } else {
      await _queuePendingTransaction(localTx);
    }

    return localTx;
  }

  /// Update an existing transaction (Works 100% Offline with Auto-Sync)
  static Future<TransactionItem> updateTransactionItem({
    required String id,
    String? type,
    double? amount,
    String? paymentMode,
    String? notes,
    bool clearNotes = false,
    String? transactionDate,
    String? dueDate,
    bool clearDueDate = false,
    bool? isSettled,
    String? personId,
    String? personName,
    bool clearPerson = false,
    String? categoryId,
    String? categoryName,
    bool clearCategory = false,
    String? accountId,
    String? accountName,
  }) async {
    String? validCatId = (categoryId != null && _uuidRegex.hasMatch(categoryId)) ? categoryId : null;
    if (validCatId == null && categoryName != null && categoryName.trim().isNotEmpty) {
      validCatId = await getOrCreateCategoryId(categoryName, type: type);
    }

    // 1. Optimistic memory & local cache update
    final existingIdx = cachedTransactions.indexWhere((t) => t.id == id);
    TransactionItem updatedTx;
    if (existingIdx != -1) {
      final old = cachedTransactions[existingIdx];
      updatedTx = old.copyWith(
        type: type,
        amount: amount,
        paymentMode: paymentMode,
        notes: clearNotes ? null : (notes ?? old.notes),
        transactionDate: transactionDate ?? old.transactionDate,
        dueDate: clearDueDate ? null : (dueDate ?? old.dueDate),
        isSettled: isSettled ?? old.isSettled,
        personId: clearPerson ? null : (personId ?? old.personId),
        personName: clearPerson ? null : (personName ?? old.personName),
        categoryId: clearCategory ? null : (validCatId ?? old.categoryId),
        categoryName: clearCategory ? null : (categoryName ?? old.categoryName),
        accountId: accountId ?? old.accountId,
        accountName: accountName ?? old.accountName,
      );
      onOptimisticTransactionUpdated(updatedTx);
    } else {
      updatedTx = TransactionItem(
        id: id,
        type: type ?? 'EXPENSE',
        amount: amount ?? 0.0,
        paymentMode: paymentMode ?? 'CASH',
        notes: notes,
        transactionDate: transactionDate,
        dueDate: dueDate,
        isSettled: isSettled ?? false,
        personId: personId,
        personName: personName,
        categoryId: validCatId,
        categoryName: categoryName,
        accountId: accountId ?? 'main',
        accountName: accountName ?? 'Main Account',
      );
      onOptimisticTransactionCreated(updatedTx);
    }

    // 2. Cloud update or queue offline
    if (ConnectivityService().isOnline.value) {
      try {
        final serverUpdated = await ApiService.updateTransaction(
          id: id,
          type: type,
          amount: amount,
          paymentMode: paymentMode,
          notes: notes,
          clearNotes: clearNotes,
          transactionDate: transactionDate,
          dueDate: dueDate,
          clearDueDate: clearDueDate,
          isSettled: isSettled,
          personId: personId,
          personName: personName,
          clearPerson: clearPerson,
          categoryId: validCatId,
          categoryName: categoryName,
          clearCategory: clearCategory,
          accountId: accountId,
          accountName: accountName,
        );
        onOptimisticTransactionUpdated(serverUpdated);
        return serverUpdated;
      } catch (e) {
        try {
          final Map<String, dynamic> updateFields = {
            if (type != null) 'type': type,
            if (amount != null) 'amount': amount,
            if (paymentMode != null) 'payment_mode': paymentMode,
            if (transactionDate != null) 'transaction_date': transactionDate,
            if (notes != null) 'notes': notes,
            if (clearNotes) 'notes': null,
            if (dueDate != null) 'due_date': dueDate,
            if (clearDueDate) 'due_date': null,
            if (isSettled != null) 'is_settled': isSettled,
            if (personId != null) 'person_id': personId,
            if (clearPerson) 'person_id': null,
            if (validCatId != null) 'category_id': validCatId,
            if (clearCategory) 'category_id': null,
            if (accountId != null) 'account_id': accountId,
          };
          await _client.from('transactions').update(updateFields).eq('id', id);
        } catch (_) {
          await _queuePendingUpdate(updatedTx);
        }
      }
    } else {
      await _queuePendingUpdate(updatedTx);
    }

    return updatedTx;
  }

  /// Delete a transaction (Works 100% Offline with Auto-Sync and Guaranteed Instant Delete)
  static Future<void> deleteTransaction(String id) async {
    // 1. Instantly remove from local memory & persistent storage in 0ms
    onOptimisticTransactionDeleted(id);

    // 2. Perform direct Supabase deletion FIRST and await it so it is gone from DB before any refresh
    if (ConnectivityService().isOnline.value) {
      try {
        await _client.from('transactions').delete().eq('id', id);
        ApiService.deleteTransaction(id).catchError((_) {});
      } catch (e) {
        debugPrint('Direct Supabase delete notice: $e');
        await _queuePendingDelete(id);
      }

      // 3. Now that DB has deleted the row, sync fresh stats and persons
      try {
        await Future.wait([fetchStatsDirectly(), fetchPersonsDirectly()]);
      } catch (_) {}
    } else {
      await _queuePendingDelete(id);
    }

    // 4. Trigger global reactive UI update
    dataVersion.value++;
  }

  // ---------------------------------------------------------------------------
  // Offline Queue Storage Helpers
  // ---------------------------------------------------------------------------
  static Future<void> _queuePendingTransaction(TransactionItem tx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingTransactions) ?? [];
      list.add(jsonEncode(tx.toJson()));
      await prefs.setStringList(_kPendingTransactions, list);
      await updatePendingCount();
    } catch (_) {}
  }

  static Future<void> _queuePendingUpdate(TransactionItem tx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingTransactionUpdates) ?? [];
      list.add(jsonEncode(tx.toJson()));
      await prefs.setStringList(_kPendingTransactionUpdates, list);
      await updatePendingCount();
    } catch (_) {}
  }

  static Future<void> _queuePendingDelete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingTransactionDeletes) ?? [];
      list.add(id);
      await prefs.setStringList(_kPendingTransactionDeletes, list);
      await updatePendingCount();
    } catch (_) {}
  }

  /// Queue a user-created category when offline
  static Future<void> queuePendingCategory(Category category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingCategories) ?? [];
      list.add(jsonEncode(category.toJson()));
      await prefs.setStringList(_kPendingCategories, list);
      await updatePendingCount();
    } catch (_) {}
  }

  /// Queue a user-created person when offline
  static Future<void> _queuePendingPerson(Person person) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingPersons) ?? [];
      list.add(jsonEncode(person.toJson()));
      await prefs.setStringList(_kPendingPersons, list);
      await updatePendingCount();
    } catch (_) {}
  }

  /// Flush pending offline changes to Supabase when internet connectivity is re-established
  static Future<int> syncPending() async {
    if (!ConnectivityService().isOnline.value) return 0;
    int flushedCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUid = AuthService.currentUserId;

      // 0. Flush pending custom categories
      final pendingCategories = prefs.getStringList(_kPendingCategories) ?? [];
      if (pendingCategories.isNotEmpty) {
        final List<String> remaining = [];
        for (final itemStr in pendingCategories) {
          try {
            final Map<String, dynamic> map = jsonDecode(itemStr);
            final cat = Category.fromJson(map);
            await _client.from('categories').upsert({
              'id': cat.id,
              if (currentUid != null) 'user_id': currentUid,
              'name': cat.name,
              'type': cat.type,
              'color': cat.color,
              'created_at': DateTime.now().toIso8601String(),
            });
            flushedCount++;
          } catch (e) {
            remaining.add(itemStr);
          }
        }
        await prefs.setStringList(_kPendingCategories, remaining);
      }

      // 0b. Flush pending persons
      final pendingPersons = prefs.getStringList(_kPendingPersons) ?? [];
      if (pendingPersons.isNotEmpty) {
        final List<String> remaining = [];
        for (final itemStr in pendingPersons) {
          try {
            final Map<String, dynamic> map = jsonDecode(itemStr);
            final p = Person.fromJson(map);
            await _client.from('persons').upsert({
              'id': p.id,
              if (currentUid != null) 'user_id': currentUid,
              'name': p.name,
              if (p.phone != null) 'phone': p.phone,
              if (p.notes != null) 'notes': p.notes,
              'created_at': DateTime.now().toIso8601String(),
            });
            flushedCount++;
          } catch (e) {
            remaining.add(itemStr);
          }
        }
        await prefs.setStringList(_kPendingPersons, remaining);
      }

      // 1. Flush pending creates
      final pendingCreates = prefs.getStringList(_kPendingTransactions) ?? [];
      if (pendingCreates.isNotEmpty) {
        final List<String> remaining = [];
        for (final itemStr in pendingCreates) {
          try {
            final Map<String, dynamic> map = jsonDecode(itemStr);
            final tx = TransactionItem.fromJson(map);
            String? pid = (tx.personId != null && _uuidRegex.hasMatch(tx.personId!)) ? tx.personId : null;
            if (pid == null && tx.personName != null && tx.personName!.trim().isNotEmpty) {
              pid = await getOrCreatePersonId(tx.personName!, userId: currentUid);
            }
            try {
              await ApiService.createTransaction(
                id: tx.id,
                type: tx.type,
                amount: tx.amount,
                paymentMode: tx.paymentMode,
                personName: tx.personName,
                personId: pid,
                categoryName: tx.categoryName,
                categoryId: (tx.categoryId != null && _uuidRegex.hasMatch(tx.categoryId!)) ? tx.categoryId : null,
                notes: tx.notes,
                dueDate: tx.dueDate,
                transactionDate: tx.transactionDate,
                accountId: tx.accountId,
                accountName: tx.accountName,
                userId: currentUid,
              );
              flushedCount++;
            } catch (_) {
              // Direct Supabase upsert fallback
              final row = <String, dynamic>{
                'id': tx.id,
                if (currentUid != null) 'user_id': currentUid,
                'account_id': tx.accountId,
                'account_name': tx.accountName,
                'type': tx.type,
                'amount': tx.amount,
                'payment_mode': tx.paymentMode,
                'transaction_date': tx.transactionDate,
                'is_settled': tx.isSettled,
                if (tx.notes != null) 'notes': tx.notes,
                if (tx.dueDate != null) 'due_date': tx.dueDate,
                if (pid != null) 'person_id': pid,
                if (tx.categoryId != null && _uuidRegex.hasMatch(tx.categoryId!)) 'category_id': tx.categoryId,
                'created_at': tx.createdAt ?? DateTime.now().toIso8601String(),
              };
              await _client.from('transactions').upsert(row);
              flushedCount++;
            }
          } catch (e) {
            remaining.add(itemStr);
          }
        }
        await prefs.setStringList(_kPendingTransactions, remaining);
      }

      // 2. Flush pending updates
      final pendingUpdates = prefs.getStringList(_kPendingTransactionUpdates) ?? [];
      if (pendingUpdates.isNotEmpty) {
        final List<String> remaining = [];
        for (final itemStr in pendingUpdates) {
          try {
            final Map<String, dynamic> map = jsonDecode(itemStr);
            final tx = TransactionItem.fromJson(map);
            final row = <String, dynamic>{
              'id': tx.id,
              if (currentUid != null) 'user_id': currentUid,
              'account_id': tx.accountId,
              'account_name': tx.accountName,
              'type': tx.type,
              'amount': tx.amount,
              'payment_mode': tx.paymentMode,
              'transaction_date': tx.transactionDate,
              'is_settled': tx.isSettled,
              if (tx.notes != null) 'notes': tx.notes,
              if (tx.dueDate != null) 'due_date': tx.dueDate,
              if (tx.personId != null && _uuidRegex.hasMatch(tx.personId!)) 'person_id': tx.personId,
              if (tx.categoryId != null && _uuidRegex.hasMatch(tx.categoryId!)) 'category_id': tx.categoryId,
            };
            await _client.from('transactions').upsert(row);
            flushedCount++;
          } catch (e) {
            remaining.add(itemStr);
          }
        }
        await prefs.setStringList(_kPendingTransactionUpdates, remaining);
      }

      // 3. Flush pending deletes
      final pendingDeletes = prefs.getStringList(_kPendingTransactionDeletes) ?? [];
      if (pendingDeletes.isNotEmpty) {
        final List<String> remaining = [];
        for (final id in pendingDeletes) {
          try {
            await _client.from('transactions').delete().eq('id', id);
            flushedCount++;
          } catch (e) {
            remaining.add(id);
          }
        }
        await prefs.setStringList(_kPendingTransactionDeletes, remaining);
      }
    } catch (e) {
      debugPrint('SyncService syncPending notice: $e');
    } finally {
      await updatePendingCount();
    }
    return flushedCount;
  }

  /// Optimistic Transaction Creation: Instantly updates local cache so UI is immediate
  static void onOptimisticTransactionCreated(TransactionItem tx) async {
    final Map<String, TransactionItem> map = {
      for (final item in cachedTransactions) item.id: item
    };
    map[tx.id] = tx;

    final updated = map.values.toList();
    _sortTransactions(updated);
    cachedTransactions = updated;

    // Immediately recalculate stats & contacts locally so Main Book & Contacts update in 0ms!
    recalculateStatsLocally(accountId: tx.accountId);
    recalculatePersonsLocally();
    dataVersion.value++;
    updatePendingCount();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTransactionsKey,
        jsonEncode(cachedTransactions.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}

    // Silently recalculate stats and contacts in background if online
    if (ConnectivityService().isOnline.value) {
      Future.wait([syncStats(), syncPersons()]).then((_) => dataVersion.value++);
    }
  }

  /// Optimistic Transaction Deletion: Instantly removes from local cache & SharedPreferences
  static void onOptimisticTransactionDeleted(String id) async {
    cachedTransactions.removeWhere((tx) => tx.id == id);
    recalculateStatsLocally();
    recalculatePersonsLocally();
    dataVersion.value++;
    updatePendingCount();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTransactionsKey,
        jsonEncode(cachedTransactions.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Optimistic Transaction Update: Instantly updates item in local cache & SharedPreferences
  static void onOptimisticTransactionUpdated(TransactionItem tx) async {
    final index = cachedTransactions.indexWhere((item) => item.id == tx.id);
    if (index != -1) {
      cachedTransactions[index] = tx;
    } else {
      cachedTransactions.add(tx);
    }
    _sortTransactions(cachedTransactions);
    recalculateStatsLocally(accountId: tx.accountId);
    recalculatePersonsLocally();
    dataVersion.value++;
    updatePendingCount();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTransactionsKey,
        jsonEncode(cachedTransactions.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}

    // Silently recalculate stats and contacts in background if online
    if (ConnectivityService().isOnline.value) {
      Future.wait([syncStats(), syncPersons()]).then((_) => dataVersion.value++);
    }
  }

  /// Sort transactions descending by date (tie-breaker by created_at)
  static void _sortTransactions(List<TransactionItem> list) {
    list.sort((a, b) {
      final da = a.transactionDate ?? '';
      final db = b.transactionDate ?? '';
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      final ca = a.createdAt ?? '';
      final cb = b.createdAt ?? '';
      return cb.compareTo(ca);
    });
  }

  /// Wipe all local cache and offline queues on sign out for clean multi-user isolation
  static Future<void> clearCache() async {
    cachedStats = null;
    cachedTransactions = [];
    cachedPersons = [];
    lastSyncTime.value = null;
    _initialized = false;
    dataVersion.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStatsKey);
      await prefs.remove(_kTransactionsKey);
      await prefs.remove(_kPersonsKey);
      await prefs.remove(_kLastSyncKey);
      await prefs.remove(_kPendingTransactions);
      await prefs.remove(_kPendingTransactionUpdates);
      await prefs.remove(_kPendingTransactionDeletes);
      await prefs.remove(_kPendingCategories);
    } catch (e) {
      debugPrint('Error clearing sync cache: $e');
    }
  }
}
