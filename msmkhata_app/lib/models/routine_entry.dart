import 'package:flutter/material.dart';

/// Predefined or User-Defined Category for Daily Routine Work
class RoutineCategory {
  final String id;
  final String name;
  final int iconCode;
  final String colorHex;
  final bool isCustom;

  const RoutineCategory({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorHex,
    this.isCustom = false,
  });

  IconData get iconData => IconData(iconCode, fontFamily: 'MaterialIcons');

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
      iconCode: json['icon_code'] is int ? json['icon_code'] : 0xe068, // Default assignment icon
      colorHex: json['color_hex']?.toString() ?? '#10B981',
      isCustom: json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'is_custom': isCustom,
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
    return RoutineEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? 'other',
      categoryName: json['category_name']?.toString() ?? 'General',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      time: json['time']?.toString(),
      notes: json['notes']?.toString(),
      hoursSpent: json['hours_spent'] != null ? double.tryParse(json['hours_spent'].toString()) : null,
      expense: json['expense'] != null ? double.tryParse(json['expense'].toString()) : null,
      isCompleted: json['is_completed'] != false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
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
