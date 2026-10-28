class Person {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final double totalGiven;
  final double totalTaken;
  final double netBalance;
  final String status; // "TO_RECEIVE", "TO_PAY", "SETTLED"
  final int transactionCount;

  Person({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    this.totalGiven = 0.0,
    this.totalTaken = 0.0,
    this.netBalance = 0.0,
    this.status = 'SETTLED',
    this.transactionCount = 0,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      notes: json['notes'],
      totalGiven: (json['total_given'] as num?)?.toDouble() ?? 0.0,
      totalTaken: (json['total_taken'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'SETTLED',
      transactionCount: json['transaction_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'total_given': totalGiven,
      'total_taken': totalTaken,
      'net_balance': netBalance,
      'status': status,
      'transaction_count': transactionCount,
    };
  }
}
