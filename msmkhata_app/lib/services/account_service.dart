import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

/// Enterprise Multi-Account / Multi-Book Management Service for MsmKhata.
///
/// Features:
/// 1. 100% Data Isolation: Each account (Book 1, Book 2, etc.) maintains strictly separate transactions.
/// 2. Deterministic Startup: Per user requirement, the app ALWAYS defaults to the Primary Account (Book 1) on every launch.
/// 3. Seamless Dynamic Accounts: Create, rename, switch, or delete books on the fly.
class AccountService {
  static const String _kAccountsKey = 'msm_saved_account_books_list';
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
    } catch (e) {
      debugPrint('AccountService init error: $e');
    }
  }

  /// Switch active working account / book
  static void switchAccount(String accountId) {
    final match = accountsNotifier.value.where((a) => a.id == accountId);
    if (match.isNotEmpty) {
      activeAccountNotifier.value = match.first;
    }
  }

  /// Create a new isolated account / book
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

    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);

    return newAccount;
  }

  /// Rename an existing account / book
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

    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);
  }

  /// Delete a book / account (Default account cannot be deleted)
  static Future<bool> deleteAccount(String accountId) async {
    if (accountId == _kDefaultAccountId) return false;

    final updated = accountsNotifier.value.where((a) => a.id != accountId).toList();
    if (updated.isEmpty) return false;

    accountsNotifier.value = updated;
    if (activeAccountNotifier.value.id == accountId) {
      activeAccountNotifier.value = updated.first;
    }

    final prefs = await SharedPreferences.getInstance();
    await _persistAccounts(prefs, updated);
    return true;
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
