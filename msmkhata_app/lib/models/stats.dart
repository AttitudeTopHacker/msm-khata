class CategoryBreakdown {
  final String? categoryId;
  final String categoryName;
  final String color;
  final double totalAmount;
  final double percentage;

  CategoryBreakdown({
    this.categoryId,
    required this.categoryName,
    required this.color,
    required this.totalAmount,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? 'Other',
      color: json['color'] ?? '#9CA3AF',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardStats {
  final double totalReceivable;
  final double totalPayable;
  final double netLenDenPosition;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final int peopleToReceiveCount;
  final int peopleToPayCount;
  final int totalTransactionsCount;
  final List<CategoryBreakdown> categoryBreakdown;

  DashboardStats({
    required this.totalReceivable,
    required this.totalPayable,
    required this.netLenDenPosition,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.peopleToReceiveCount,
    required this.peopleToPayCount,
    required this.totalTransactionsCount,
    required this.categoryBreakdown,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalReceivable: (json['total_receivable'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['total_payable'] as num?)?.toDouble() ?? 0.0,
      netLenDenPosition: (json['net_len_den_position'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      netSavings: (json['net_savings'] as num?)?.toDouble() ?? 0.0,
      peopleToReceiveCount: json['people_to_receive_from_count'] ?? 0,
      peopleToPayCount: json['people_to_pay_to_count'] ?? 0,
      totalTransactionsCount: json['total_transactions_count'] ?? 0,
      categoryBreakdown: (json['category_breakdown'] as List<dynamic>?)
              ?.map((item) => CategoryBreakdown.fromJson(item))
              .toList() ??
          [],
    );
  }
}
