import 'package:flutter/material.dart';

/// Predefined or User-Defined Category for Daily Routine Work
class RoutineCategory {
  final String id;
  final String name;
  final String iconKey;
  final int iconCode;
  final String colorHex;
  final bool isCustom;

  const RoutineCategory({
    required this.id,
    required this.name,
    this.iconKey = 'general',
    this.iconCode = 0xe068,
    required this.colorHex,
    this.isCustom = false,
  });

  /// Compile-time constant icon lookup for tree-shaking safety
  static const Map<String, IconData> iconMap = {
    'agriculture': Icons.agriculture_rounded,
    'trip': Icons.directions_car_rounded,
    'car': Icons.directions_car_rounded,
    'market': Icons.shopping_bag_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'office': Icons.work_rounded,
    'work': Icons.work_rounded,
    'personal': Icons.home_rounded,
    'home': Icons.home_rounded,
    'fitness': Icons.fitness_center_rounded,
    'school': Icons.school_rounded,
    'construction': Icons.construction_rounded,
    'medical': Icons.medical_services_rounded,
    'restaurant': Icons.restaurant_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'build': Icons.build_rounded,
    'computer': Icons.computer_rounded,
    'handshake': Icons.handshake_rounded,
    'payments': Icons.payments_rounded,
    'general': Icons.task_alt_rounded,
  };

  IconData get iconData {
    if (iconMap.containsKey(iconKey)) {
      return iconMap[iconKey]!;
    }
    if (iconMap.containsKey(id)) {
      return iconMap[id]!;
    }
    return Icons.task_alt_rounded;
  }

  Color get color {
    try {
      final clean = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  factory RoutineCategory.fromJson(Map<String, dynamic> json) {
    return RoutineCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'General',
      iconKey: json['icon_key']?.toString() ?? json['id']?.toString() ?? 'general',
      iconCode: json['icon_code'] is int ? json['icon_code'] : 0xe068,
      colorHex: json['color_hex']?.toString() ?? '#10B981',
      isCustom: json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_key': iconKey,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'is_custom': isCustom,
    };
  }

  Map<String, dynamic> toSupabaseJson(String? userId) {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'icon_key': iconKey,
      'color_hex': colorHex,
      'is_custom': isCustom,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Single Logged Work / Routine Entry for a Day
class RoutineEntry {
  final String id;
  final String title;
  final String categoryId;
  final String categoryName;
  final DateTime date;
  final String? time;
  final String? notes;
  final double? hoursSpent;
  final double? expense;
  final bool isCompleted;
  final DateTime createdAt;

  RoutineEntry({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.date,
    this.time,
    this.notes,
    this.hoursSpent,
    this.expense,
    this.isCompleted = true,
    required this.createdAt,
  });

  factory RoutineEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final rawDate = json['entry_date'] ?? json['date'];
    if (rawDate != null) {
      try {
        final rawStr = rawDate.toString().split('T')[0].split(' ')[0];
        final parts = rawStr.split('-');
        if (parts.length == 3) {
          parsedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          parsedDate = DateTime.tryParse(rawStr) ?? DateTime.now();
        }
      } catch (_) {}
    }

    return RoutineEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? 'other',
      categoryName: json['category_name']?.toString() ?? 'General',
      date: parsedDate,
      time: (json['entry_time'] ?? json['time'])?.toString(),
      notes: json['notes']?.toString(),
      hoursSpent: json['hours_spent'] != null ? double.tryParse(json['hours_spent'].toString()) : null,
      expense: json['expense'] != null ? double.tryParse(json['expense'].toString()) : null,
      isCompleted: json['is_completed'] != false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson(String? userId) {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'category_id': categoryId,
      'category_name': categoryName,
      'entry_date': date.toIso8601String().split('T')[0],
      'entry_time': time,
      'notes': notes,
      'hours_spent': hoursSpent,
      'expense': expense,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category_id': categoryId,
      'category_name': categoryName,
      'date': date.toIso8601String(),
      'time': time,
      'notes': notes,
      'hours_spent': hoursSpent,
      'expense': expense,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RoutineEntry copyWith({
    String? title,
    String? categoryId,
    String? categoryName,
    DateTime? date,
    String? time,
    String? notes,
    double? hoursSpent,
    double? expense,
    bool? isCompleted,
  }) {
    return RoutineEntry(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      hoursSpent: hoursSpent ?? this.hoursSpent,
      expense: expense ?? this.expense,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}

