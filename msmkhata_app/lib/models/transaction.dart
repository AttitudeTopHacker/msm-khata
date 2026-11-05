class TransactionItem {
  final String id;
  final String type; // "GIVEN", "TAKEN", "EXPENSE", "INCOME"
  final double amount;
  final String paymentMode;
  final String? dueDate;
  final bool isSettled;
  final String? notes;
  final String? transactionDate;
  final String? personId;
  final String? personName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String accountId;
  final String accountName;
  final String? createdAt;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    this.paymentMode = 'CASH',
    this.dueDate,
    this.isSettled = false,
    this.notes,
    this.transactionDate,
    this.personId,
    this.personName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.accountId = 'main',
    this.accountName = 'Main Account',
    this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'EXPENSE',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] ?? 'CASH',
      dueDate: json['due_date'],
      isSettled: json['is_settled'] ?? false,
      notes: json['notes'],
      transactionDate: json['transaction_date'],
      personId: json['person_id'],
      personName: json['person_name'],
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      categoryColor: json['category_color'],
      accountId: json['account_id'] ?? 'main',
      accountName: json['account_name'] ?? 'Main Account',
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'payment_mode': paymentMode,
      'due_date': dueDate,
      'is_settled': isSettled,
      'notes': notes,
      'transaction_date': transactionDate,
      'person_id': personId,
      'person_name': personName,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_color': categoryColor,
      'account_id': accountId,
      'account_name': accountName,
      'created_at': createdAt,
    };
  }

  TransactionItem copyWith({
    String? id,
    String? type,
    double? amount,
    String? paymentMode,
    String? dueDate,
    bool? isSettled,
    String? notes,
    String? transactionDate,
    String? personId,
    String? personName,
    String? categoryId,
    String? categoryName,
    String? categoryColor,
    String? accountId,
    String? accountName,
    String? createdAt,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      dueDate: dueDate ?? this.dueDate,
      isSettled: isSettled ?? this.isSettled,
      notes: notes ?? this.notes,
      transactionDate: transactionDate ?? this.transactionDate,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
