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

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'category_name': categoryName,
      'color': color,
      'total_amount': totalAmount,
      'percentage': percentage,
    };
  }
}

class PersonBalanceSummary {
  final String personId;
  final String name;
  final double totalGiven;
  final double totalTaken;
  final double netBalance;
  final String status;

  PersonBalanceSummary({
    required this.personId,
    required this.name,
    required this.totalGiven,
    required this.totalTaken,
    required this.netBalance,
    required this.status,
  });

  factory PersonBalanceSummary.fromJson(Map<String, dynamic> json) {
    return PersonBalanceSummary(
      personId: json['person_id'] ?? '',
      name: json['name'] ?? '',
      totalGiven: (json['total_given'] as num?)?.toDouble() ?? 0.0,
      totalTaken: (json['total_taken'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'name': name,
      'total_given': totalGiven,
      'total_taken': totalTaken,
      'net_balance': netBalance,
      'status': status,
    };
  }
}

class MonthlyTrendItem {
  final String month; // e.g. "2026-10"
  final double totalIncome;
  final double totalExpense;
  final double totalGiven;
  final double totalTaken;

  MonthlyTrendItem({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalGiven,
    required this.totalTaken,
  });

  factory MonthlyTrendItem.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendItem(
      month: json['month'] ?? '',
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      totalGiven: (json['total_given'] as num?)?.toDouble() ?? 0.0,
      totalTaken: (json['total_taken'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'total_given': totalGiven,
      'total_taken': totalTaken,
    };
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
  final List<PersonBalanceSummary> topDebtors;
  final List<PersonBalanceSummary> topCreditors;
  final List<MonthlyTrendItem> monthlyTrends;

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
    required this.topDebtors,
    required this.topCreditors,
    required this.monthlyTrends,
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
      topDebtors: (json['top_debtors'] as List<dynamic>?)
              ?.map((item) => PersonBalanceSummary.fromJson(item))
              .toList() ??
          [],
      topCreditors: (json['top_creditors'] as List<dynamic>?)
              ?.map((item) => PersonBalanceSummary.fromJson(item))
              .toList() ??
          [],
      monthlyTrends: (json['monthly_trends'] as List<dynamic>?)
              ?.map((item) => MonthlyTrendItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_receivable': totalReceivable,
      'total_payable': totalPayable,
      'net_len_den_position': netLenDenPosition,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'net_savings': netSavings,
      'people_to_receive_from_count': peopleToReceiveCount,
      'people_to_pay_to_count': peopleToPayCount,
      'total_transactions_count': totalTransactionsCount,
      'category_breakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
      'top_debtors': topDebtors.map((e) => e.toJson()).toList(),
      'top_creditors': topCreditors.map((e) => e.toJson()).toList(),
      'monthly_trends': monthlyTrends.map((e) => e.toJson()).toList(),
    };
  }
}
