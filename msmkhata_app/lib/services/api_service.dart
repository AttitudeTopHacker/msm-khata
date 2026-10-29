import 'dart:convert';
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

  // 6. Update Transaction (Edit Date, Amount, Notes, etc.)
  static Future<TransactionItem> updateTransaction({
    required String id,
    double? amount,
    String? paymentMode,
    String? notes,
    String? transactionDate,
    String? dueDate,
    bool? isSettled,
  }) async {
    final payload = <String, dynamic>{
      if (amount != null) 'amount': amount,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (notes != null) 'notes': notes,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (dueDate != null) 'due_date': dueDate,
      if (isSettled != null) 'is_settled': isSettled,
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
    Category(id: 'c1', name: 'Market', type: 'BOTH', color: '#3B82F6'),
    Category(id: 'c2', name: 'Mandi', type: 'BOTH', color: '#10B981'),
    Category(id: 'c3', name: 'Agriculture', type: 'BOTH', color: '#84CC16'),
    Category(id: 'c4', name: 'Ploughing', type: 'EXPENSE', color: '#D97706'),
    Category(id: 'c5', name: 'Irrigation', type: 'EXPENSE', color: '#06B6D4'),
    Category(id: 'c6', name: 'Diesel', type: 'EXPENSE', color: '#EF4444'),
    Category(id: 'c7', name: 'Fertiliser & Seeds', type: 'EXPENSE', color: '#14B8A6'),
    Category(id: 'c8', name: 'Labour', type: 'EXPENSE', color: '#8B5CF6'),
    Category(id: 'c9', name: 'Household Expenses', type: 'EXPENSE', color: '#F59E0B'),
    Category(id: 'c10', name: 'General', type: 'BOTH', color: '#64748B'),
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
          return fetched;
        }
      }
    } catch (_) {
      // Return defaults on error
    }
    return defaultCategories;
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
}
