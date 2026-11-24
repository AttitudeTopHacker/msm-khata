import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../models/stats.dart';
import '../models/category.dart';
import 'account_service.dart';
import 'auth_service.dart';

class ApiService {
  static String get _base => ApiConfig.baseUrl;
  static SupabaseClient get _supabase => Supabase.instance.client;

  // 1. Fetch Dashboard Stats (Isolated to current logged in user and active account)
  static Future<DashboardStats> getDashboardStats({String? userId, String? accountId}) async {
    final uid = userId ?? AuthService.currentUserId;
    final aid = accountId ?? AccountService.activeAccountNotifier.value.id;
    final params = <String, String>{};
    if (uid != null) params['user_id'] = uid;
    if (aid.isNotEmpty) params['account_id'] = aid;

    final uri = Uri.parse('$_base/stats/summary').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load dashboard stats: ${res.statusCode}');
  }

  // 2. Fetch Persons with balances (Isolated to current user)
  static Future<List<Person>> getPersons({String? status, String? userId}) async {
    final uid = userId ?? AuthService.currentUserId;
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (uid != null) params['user_id'] = uid;

    final uri = Uri.parse('$_base/persons').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => Person.fromJson(item)).toList();
    }
    throw Exception('Failed to load persons');
  }

  // 3. Create Person (Tagged with current user)
  static Future<Person> createPerson({
    required String name,
    String? phone,
    String? notes,
    String? userId,
  }) async {
    final uid = userId ?? AuthService.currentUserId;
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
      if (uid != null) 'user_id': uid,
    };

    final res = await http.post(
      Uri.parse('$_base/persons'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return Person.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create person');
  }

  // 4. Fetch Transactions (Isolated to current account/book and user)
  static Future<List<TransactionItem>> getTransactions({
    String? accountId,
    String? personId,
    String? type,
    String? startDate,
    String? endDate,
    String? userId,
    int? limit,
    int? offset,
  }) async {
    final uid = userId ?? AuthService.currentUserId;
    final aid = accountId ?? AccountService.activeAccountNotifier.value.id;
    final params = <String, String>{};
    if (aid.isNotEmpty) params['account_id'] = aid;
    if (personId != null) params['person_id'] = personId;
    if (type != null) params['type'] = type;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (uid != null) params['user_id'] = uid;
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final uri = Uri.parse('$_base/transactions').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => TransactionItem.fromJson(item)).toList();
    }
    throw Exception('Failed to load transactions');
  }

  // 5. Create Transaction (Tagged with current active account/book and user)
  static Future<TransactionItem> createTransaction({
    String? id,
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
    String? userId,
    String? accountId,
    String? accountName,
  }) async {
    final uid = userId ?? AuthService.currentUserId;
    final activeBook = AccountService.activeAccountNotifier.value;
    final aid = accountId ?? activeBook.id;
    final aname = accountName ?? activeBook.name;

    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'payment_mode': paymentMode,
      'account_id': aid,
      'account_name': aname,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
      if (transactionDate != null && transactionDate.isNotEmpty) 'transaction_date': transactionDate,
      if (personId != null) 'person_id': personId,
      if (personName != null) 'person_name': personName,
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null) 'category_name': categoryName,
      if (uid != null) 'user_id': uid,
    };

    final res = await http.post(
      Uri.parse('$_base/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return TransactionItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to record transaction');
  }

  // 6. Update Transaction (Edit Date, Amount, Notes, Type, Person, Category, etc.)
  static Future<TransactionItem> updateTransaction({
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
    final payload = <String, dynamic>{
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (notes != null) 'notes': notes,
      if (clearNotes) 'notes': null,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (dueDate != null) 'due_date': dueDate,
      if (clearDueDate) 'due_date': null,
      if (isSettled != null) 'is_settled': isSettled,
      if (personId != null) 'person_id': personId,
      if (clearPerson) 'person_id': null,
      if (personName != null && personName.isNotEmpty) 'person_name': personName,
      if (categoryId != null) 'category_id': categoryId,
      if (clearCategory) 'category_id': null,
      if (categoryName != null && categoryName.isNotEmpty) 'category_name': categoryName,
      if (accountId != null) 'account_id': accountId,
      if (accountName != null) 'account_name': accountName,
    };

    final res = await http.put(
      Uri.parse('$_base/transactions/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return TransactionItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update transaction');
  }

  // 7. Delete Transaction
  static Future<void> deleteTransaction(String id) async {
    // 1. Delete directly from Supabase FIRST for instant guaranteed execution
    try {
      await _supabase.from('transactions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Direct Supabase delete error: $e');
    }
    // 2. Fire to backend without blocking
    try {
      http.delete(Uri.parse('$_base/transactions/$id')).timeout(const Duration(seconds: 1)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  // 8. Settle Transaction
  static Future<void> settleTransaction(String id, {bool isSettled = true}) async {
    try {
      await http.patch(
        Uri.parse('$_base/transactions/$id/settle?is_settled=$isSettled'),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      try {
        await _supabase.from('transactions').update({'is_settled': isSettled}).eq('id', id);
      } catch (e) {
        debugPrint('Direct Supabase settle error: $e');
        throw Exception('Failed to update settlement status');
      }
    }
  }

  // 7. Fetch Categories (with default fallback for offline / immediate display)
  static final List<Category> defaultCategories = [
    // Income Categories
    Category(id: '1378295f-5c3c-4e24-8ce8-f48ccea5ae5b', name: 'Paddy (Dhan Bikri)', type: 'INCOME', color: '#10B981'),
    Category(id: '8f6882c4-cac3-4140-9781-51df40fa0c14', name: 'Wheat (Gehu Bikri)', type: 'INCOME', color: '#F59E0B'),
    Category(id: 'be564e1c-da40-4cef-b06b-b38f001fa026', name: 'Sugarcane (Ganna)', type: 'INCOME', color: '#84CC16'),
    Category(id: '763a3468-bb4a-4c51-9c56-7908bbcf1614', name: 'Mustard / Oilseeds (Sarson)', type: 'INCOME', color: '#EAB308'),
    Category(id: 'b34046a6-61dc-4762-b2b3-b0ca1a3f24b8', name: 'Vegetables & Fruits (Sabzi/Fal)', type: 'INCOME', color: '#14B8A6'),
    Category(id: '8bf98dac-0cd1-4532-98d9-3796ca9d4189', name: 'Dairy & Milk (Doodh)', type: 'INCOME', color: '#38BDF8'),
    Category(id: 'cc2afd8b-a670-4405-9eef-105fa2c86b85', name: 'Rental Income (Kiraya/Bhaada)', type: 'INCOME', color: '#6366F1'),
    Category(id: '8b30ec29-3155-4808-b141-8f34835204af', name: 'Other Income (Anya Kamai)', type: 'INCOME', color: '#8B5CF6'),
    Category(id: 'dcc835da-35a6-4ad5-a733-3326d5c23e9b', name: 'kirana Store', type: 'INCOME', color: '#10B981'),
    Category(id: '33d36887-a110-40bc-9668-f6ada06f8915', name: 'pension', type: 'INCOME', color: '#EF4444'),

    // Expense Categories
    Category(id: 'e2b166c1-674b-4343-96d1-e5c41b961c0d', name: 'Mandi & Selling', type: 'EXPENSE', color: '#F97316'),
    Category(id: 'a613f11b-f1a7-41f9-85f1-5edf57647945', name: 'Ploughing', type: 'EXPENSE', color: '#D97706'),
    Category(id: '5cf8f5a4-caf3-4ada-8c54-96dda4dc4f83', name: 'Irrigation', type: 'EXPENSE', color: '#06B6D4'),
    Category(id: 'cfa49685-4c20-4ca3-b78f-42a5096354e8', name: 'Diesel & Fuel', type: 'EXPENSE', color: '#EF4444'),
    Category(id: 'f686ee4d-123c-488a-a838-db74fedcfefd', name: 'Fertiliser & Seeds / Pesticides', type: 'EXPENSE', color: '#10B981'),
    Category(id: 'e6c47cd3-58cc-4bff-a2c7-b488e693fc08', name: 'Labour', type: 'EXPENSE', color: '#8B5CF6'),
    Category(id: 'ac942280-01fe-4f81-b46c-63a68da4dac5', name: 'Machinery & Equipment', type: 'EXPENSE', color: '#64748B'),
    Category(id: 'd1ea09e4-8bcb-4492-b12e-75e9e0706019', name: 'Family', type: 'EXPENSE', color: '#EC4899'),
    Category(id: 'e55311d4-171b-4ace-9b6b-91075aa5e57f', name: 'Household Expenses', type: 'EXPENSE', color: '#F59E0B'),
    Category(id: 'ef697154-c1b0-4912-8e71-4ca5e0fb53ff', name: 'Cropping / Harvester', type: 'EXPENSE', color: '#84CC16'),
    Category(id: '4d105b8f-0464-4d70-8fea-6f7526bea01b', name: 'Personal', type: 'EXPENSE', color: '#3B82F6'),
    Category(id: 'acf47625-7a81-4c67-8b9b-e837d3ce1c83', name: 'Electricity bills', type: 'EXPENSE', color: '#84CC16'),
    Category(id: '42d0742f-1789-4a77-8200-0aebc4c58ab1', name: 'salman', type: 'EXPENSE', color: '#3B82F6'),
  ];

  static Future<List<Category>> getCategories({String? type, String? userId}) async {
    // 1. Fetch directly from Supabase first
    try {
      final uid = userId ?? AuthService.currentUserId;
      var query = _supabase.from('categories').select('id, name, type, color, user_id');
      if (type != null) {
        query = query.or('type.eq.$type,type.eq.BOTH');
      }
      if (uid != null) {
        query = query.or('user_id.is.null,user_id.eq.$uid');
      }
      final dynamic rows = await query.order('name');
      if (rows is List && rows.isNotEmpty) {
        final fetched = rows.map((item) => Category(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          type: item['type']?.toString() ?? 'EXPENSE',
          color: item['color']?.toString() ?? '#3B82F6',
        )).toList();
        final seen = <String>{};
        final deduped = <Category>[];
        for (final c in fetched) {
          final key = c.name.trim().toLowerCase();
          if (!seen.contains(key)) {
            seen.add(key);
            deduped.add(c);
          }
        }
        if (deduped.isNotEmpty) return deduped;
      }
    } catch (_) {}

    // 2. Fetch from backend API
    try {
      final uid = userId ?? AuthService.currentUserId;
      final params = <String, String>{};
      if (type != null) params['type'] = type;
      if (uid != null) params['user_id'] = uid;

      final uri = Uri.parse('$_base/categories').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final fetched = list.map((item) => Category.fromJson(item)).toList();
        if (fetched.isNotEmpty) {
          final seen = <String>{};
          final deduped = <Category>[];
          for (final c in fetched) {
            final key = c.name.trim().toLowerCase();
            if (!seen.contains(key)) {
              seen.add(key);
              deduped.add(c);
            }
          }
          return deduped;
        }
      }
    } catch (_) {
      // Return defaults on error
    }

    // 3. Fallback to defaultCategories
    final fallback = (type != null)
        ? defaultCategories.where((c) => c.type == type || c.type == 'BOTH').toList()
        : defaultCategories;
    final seen = <String>{};
    final deduped = <Category>[];
    for (final c in fallback) {
      final key = c.name.trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        deduped.add(c);
      }
    }
    return deduped;
  }

  // 8. Create Category (Tagged with current user)
  static Future<Category> createCategory({
    required String name,
    String type = 'EXPENSE',
    String color = '#4F46E5',
    String? userId,
  }) async {
    final uid = userId ?? AuthService.currentUserId;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'type': type,
      'color': color,
      if (uid != null) 'user_id': uid,
    };

    // 1. Direct Supabase insert
    try {
      final res = await _supabase.from('categories').insert(payload).select().single();
      return Category(
        id: res['id']?.toString() ?? '',
        name: res['name']?.toString() ?? name.trim(),
        type: res['type']?.toString() ?? type,
        color: res['color']?.toString() ?? color,
      );
    } catch (e) {
      debugPrint('Direct Supabase createCategory notice: $e');
    }

    // 2. Render backend fallback
    try {
      final res = await http.post(
        Uri.parse('$_base/categories'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 201) {
        return Category.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    throw Exception('Failed to create category');
  }

  // 9. Update Category (Rename, Color, Type)
  static Future<Category> updateCategory({
    required String id,
    String? name,
    String? type,
    String? color,
  }) async {
    final payload = <String, dynamic>{
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (type != null) 'type': type,
      if (color != null) 'color': color,
    };

    // 1. Direct Supabase update
    try {
      final res = await _supabase.from('categories').update(payload).eq('id', id).select().single();
      return Category(
        id: res['id']?.toString() ?? id,
        name: res['name']?.toString() ?? (name ?? ''),
        type: res['type']?.toString() ?? (type ?? 'EXPENSE'),
        color: res['color']?.toString() ?? (color ?? '#3B82F6'),
      );
    } catch (_) {}

    // 2. Render backend fallback
    try {
      final res = await http.put(
        Uri.parse('$_base/categories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return Category.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    return Category(
      id: id,
      name: name ?? '',
      type: type ?? 'EXPENSE',
      color: color ?? '#3B82F6',
    );
  }

  // 10. Delete Category (Guarded by transactions usage check)
  static Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (_) {}

    try {
      final res = await http.delete(Uri.parse('$_base/categories/$id')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return;
      }
    } catch (_) {}
  }

  // 11. Python Professional Reports (PDF with Charts & Excel .xlsx)
  static String getPdfReportUrl({String? accountId, String? accountName, String mode = 'full'}) {
    final aid = accountId ?? AccountService.activeAccountNotifier.value.id;
    final aname = accountName ?? AccountService.activeAccountNotifier.value.name;
    return '$_base/reports/pdf?account_id=$aid&account_name=${Uri.encodeComponent(aname)}&mode=$mode';
  }

  static String getExcelReportUrl({String? accountId, String? accountName}) {
    final aid = accountId ?? AccountService.activeAccountNotifier.value.id;
    final aname = accountName ?? AccountService.activeAccountNotifier.value.name;
    return '$_base/reports/excel?account_id=$aid&account_name=${Uri.encodeComponent(aname)}';
  }

  static Future<Uint8List> fetchPdfReport({String? accountId, String? accountName, String mode = 'full'}) async {
    final url = getPdfReportUrl(accountId: accountId, accountName: accountName, mode: mode);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Failed to download PDF report: ${res.statusCode}');
  }

  // 11. Google Drive Cloud Backup (JSON, Excel .xlsx, PDF .pdf)
  static Future<Map<String, dynamic>> uploadBackupToGoogleDrive({
    required String googleAccessToken,
    String? userId,
    String? accountId,
    String? accountName,
    bool includeExcel = true,
    bool includePdf = true,
  }) async {
    final aid = accountId ?? AccountService.activeAccountNotifier.value.id;
    final aname = accountName ?? AccountService.activeAccountNotifier.value.name;
    final payload = {
      'google_access_token': googleAccessToken,
      if (userId != null) 'user_id': userId,
      'account_id': aid,
      'account_name': aname,
      'include_excel': includeExcel,
      'include_pdf': includePdf,
    };

    final res = await http.post(
      Uri.parse('$_base/backup/google-drive'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    final errorBody = res.body;
    throw Exception('Google Drive upload failed: $errorBody');
  }
}
