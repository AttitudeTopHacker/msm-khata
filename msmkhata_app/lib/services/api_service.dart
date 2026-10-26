import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../models/stats.dart';

class ApiService {
  static final String _base = ApiConfig.baseUrl;

  // 1. Fetch Dashboard Stats
  static Future<DashboardStats> getDashboardStats({String? userId}) async {
    final uri = Uri.parse('$_base/stats/summary${userId != null ? '?user_id=$userId' : ''}');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load dashboard stats: ${res.statusCode}');
  }

  // 2. Fetch Persons with balances
  static Future<List<Person>> getPersons({String? status, String? userId}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (userId != null) params['user_id'] = userId;

    final uri = Uri.parse('$_base/persons').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => Person.fromJson(item)).toList();
    }
    throw Exception('Failed to load persons');
  }

  // 3. Create Person
  static Future<Person> createPerson({required String name, String? phone, String? notes}) async {
    final res = await http.post(
      Uri.parse('$_base/persons'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone, 'notes': notes}),
    );
    if (res.statusCode == 201) {
      return Person.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create person');
  }

  // 4. Fetch Transactions
  static Future<List<TransactionItem>> getTransactions({
    String? personId,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (personId != null) params['person_id'] = personId;
    if (type != null) params['type'] = type;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final uri = Uri.parse('$_base/transactions').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => TransactionItem.fromJson(item)).toList();
    }
    throw Exception('Failed to load transactions');
  }

  // 5. Create Transaction (Supports dynamic on-the-fly person/category)
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
  }) async {
    final payload = {
      'type': type,
      'amount': amount,
      'payment_mode': paymentMode,
      'notes': notes,
      'due_date': dueDate,
    };
    if (personId != null) payload['person_id'] = personId;
    if (personName != null) payload['person_name'] = personName;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (categoryName != null) payload['category_name'] = categoryName;

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

  // 6. Settle Transaction
  static Future<void> settleTransaction(String id, {bool isSettled = true}) async {
    await http.patch(
      Uri.parse('$_base/transactions/$id/settle?is_settled=$isSettled'),
    );
  }
}
