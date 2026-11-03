class GroceryStore {
  final String id;
  final String? userId;
  final String storeName;
  final String category;
  final String? notes;
  final DateTime createdAt;

  // Dynamic ledger aggregates
  double totalUdhaar;
  double totalChukaya;
  int entriesCount;

  GroceryStore({
    required this.id,
    this.userId,
    required this.storeName,
    this.category = 'General',
    this.notes,
    required this.createdAt,
    this.totalUdhaar = 0.0,
    this.totalChukaya = 0.0,
    this.entriesCount = 0,
  });

  double get pendingBalance => (totalUdhaar - totalChukaya).clamp(0.0, double.infinity);
  bool get isSettled => pendingBalance <= 0.01 && entriesCount > 0;

  factory GroceryStore.fromJson(Map<String, dynamic> json) {
    return GroceryStore(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      storeName: json['store_name']?.toString() ?? 'Store',
      category: json['category']?.toString() ?? 'General',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalUdhaar: (json['total_udhaar'] as num?)?.toDouble() ?? 0.0,
      totalChukaya: (json['total_chukaya'] as num?)?.toDouble() ?? 0.0,
      entriesCount: (json['entries_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'store_name': storeName,
      'category': category,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class GroceryEntry {
  final String id;
  final String storeId;
  final String? userId;
  final String type; // 'UDHAAR' or 'CHUKAYA'
  final double amount;
  final String itemsDescription; // Price aur kya cheez
  final DateTime entryDate;
  final DateTime createdAt;

  GroceryEntry({
    required this.id,
    required this.storeId,
    this.userId,
    required this.type,
    required this.amount,
    required this.itemsDescription,
    required this.entryDate,
    required this.createdAt,
  });

  bool get isUdhaar => type == 'UDHAAR';
  bool get isChukaya => type == 'CHUKAYA';

  factory GroceryEntry.fromJson(Map<String, dynamic> json) {
    return GroceryEntry(
      id: json['id']?.toString() ?? '',
      storeId: json['store_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      type: json['type']?.toString() ?? 'UDHAAR',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      itemsDescription: json['items_description']?.toString() ?? '',
      entryDate: json['entry_date'] != null
          ? DateTime.tryParse(json['entry_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      if (userId != null) 'user_id': userId,
      'type': type,
      'amount': amount,
      'items_description': itemsDescription,
      'entry_date': entryDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

