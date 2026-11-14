import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../models/stats.dart';
import '../models/category.dart';
import 'account_service.dart';
import 'auth_service.dart';

class ApiService {
  static String get _base => ApiConfig.baseUrl;

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
    final res = await http.delete(Uri.parse('$_base/transactions/$id'));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete transaction');
    }
  }

  // 8. Settle Transaction
  static Future<void> settleTransaction(String id, {bool isSettled = true}) async {
    await http.patch(
      Uri.parse('$_base/transactions/$id/settle?is_settled=$isSettled'),
    );
  }

  // 7. Fetch Categories (with default fallback for offline / immediate display)
  static final List<Category> defaultCategories = [
    // Income Categories
    Category(id: 'c_inc_1', name: 'Paddy (Dhan Bikri)', type: 'INCOME', color: '#10B981'),
    Category(id: 'c_inc_2', name: 'Wheat (Gehu Bikri)', type: 'INCOME', color: '#F59E0B'),
    Category(id: 'c_inc_3', name: 'Sugarcane (Ganna)', type: 'INCOME', color: '#84CC16'),
    Category(id: 'c_inc_4', name: 'Mustard / Oilseeds (Sarson)', type: 'INCOME', color: '#EAB308'),
    Category(id: 'c_inc_5', name: 'Vegetables & Fruits (Sabzi/Fal)', type: 'INCOME', color: '#14B8A6'),
    Category(id: 'c_inc_6', name: 'Dairy & Milk (Doodh)', type: 'INCOME', color: '#38BDF8'),
    Category(id: 'c_inc_7', name: 'Rental Income (Kiraya/Bhaada)', type: 'INCOME', color: '#6366F1'),
    Category(id: 'c_inc_8', name: 'Other Income (Anya Kamai)', type: 'INCOME', color: '#8B5CF6'),

    // Expense Categories
    Category(id: 'c_exp_1', name: 'Mandi & Selling', type: 'EXPENSE', color: '#F97316'),
    Category(id: 'c_exp_2', name: 'Ploughing', type: 'EXPENSE', color: '#D97706'),
    Category(id: 'c_exp_3', name: 'Irrigation', type: 'EXPENSE', color: '#06B6D4'),
    Category(id: 'c_exp_4', name: 'Diesel & Fuel', type: 'EXPENSE', color: '#EF4444'),
    Category(id: 'c_exp_5', name: 'Fertiliser & Seeds / Pesticides', type: 'EXPENSE', color: '#10B981'),
    Category(id: 'c_exp_6', name: 'Labour', type: 'EXPENSE', color: '#8B5CF6'),
    Category(id: 'c_exp_7', name: 'Machinery & Equipment', type: 'EXPENSE', color: '#64748B'),
    Category(id: 'c_exp_8', name: 'Family', type: 'EXPENSE', color: '#EC4899'),
    Category(id: 'c_exp_9', name: 'Household Expenses', type: 'EXPENSE', color: '#F59E0B'),
    Category(id: 'c_exp_10', name: 'Cropping / Harvester', type: 'EXPENSE', color: '#84CC16'),
    Category(id: 'c_exp_11', name: 'Personal', type: 'EXPENSE', color: '#3B82F6'),
  ];

  static Future<List<Category>> getCategories({String? type, String? userId}) async {
    try {
      final uid = userId ?? AuthService.currentUserId;
      final params = <String, String>{};
      if (type != null) params['type'] = type;
      if (uid != null) params['user_id'] = uid;

      final uri = Uri.parse('$_base/categories').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri);
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

    final res = await http.post(
      Uri.parse('$_base/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return Category.fromJson(jsonDecode(res.body));
    }
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

    final res = await http.put(
      Uri.parse('$_base/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      return Category.fromJson(jsonDecode(res.body));
    }
    try {
      final err = jsonDecode(res.body);
      if (err is Map && err['detail'] != null) {
        throw Exception(err['detail']);
      }
    } catch (e) {
      if (e is! FormatException) rethrow;
    }
    throw Exception('Failed to update category');
  }

  // 10. Delete Category (Guarded by transactions usage check)
  static Future<void> deleteCategory(String id) async {
    final res = await http.delete(Uri.parse('$_base/categories/$id'));
    if (res.statusCode == 204 || res.statusCode == 200) {
      return;
    }

    try {
      final err = jsonDecode(res.body);
      if (err is Map && err['detail'] != null) {
        throw Exception(err['detail']);
      }
    } catch (e) {
      if (e is! FormatException) rethrow;
    }
    throw Exception('Failed to delete category');
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
