import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine_entry.dart';

/// Service managing Daily Routine Work Diary & Custom Categories
class RoutineService {
  static const String _kEntriesKey = 'msm_routine_entries_v1';
  static const String _kCustomCategoriesKey = 'msm_routine_custom_categories_v1';

  /// 5 Default Inbuilt Categories
  static final List<RoutineCategory> defaultCategories = [
    RoutineCategory(
      id: 'agriculture',
      name: 'Agriculture & Kheti',
      iconCode: Icons.agriculture_rounded.codePoint,
      colorHex: '#10B981',
      isCustom: false,
    ),
    RoutineCategory(
      id: 'trip',
      name: 'Trip & Travel',
      iconCode: Icons.directions_car_rounded.codePoint,
      colorHex: '#38BDF8',
      isCustom: false,
    ),
    RoutineCategory(
      id: 'market',
      name: 'Market & Shopping',
      iconCode: Icons.shopping_bag_rounded.codePoint,
      colorHex: '#F59E0B',
      isCustom: false,
    ),
    RoutineCategory(
      id: 'office',
      name: 'Office & Business',
      iconCode: Icons.work_rounded.codePoint,
      colorHex: '#8B5CF6',
      isCustom: false,
    ),
    RoutineCategory(
      id: 'personal',
      name: 'Personal & Home',
      iconCode: Icons.home_rounded.codePoint,
      colorHex: '#EC4899',
      isCustom: false,
    ),
  ];

  static List<RoutineCategory> allCategories = List.from(defaultCategories);
  static List<RoutineEntry> cachedEntries = [];
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  static bool _initialized = false;

  /// Helper: Generate RFC 4122 v4 UUID
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Initialize local routine diary cache on startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load custom categories
      final customCatsStr = prefs.getString(_kCustomCategoriesKey);
      if (customCatsStr != null && customCatsStr.isNotEmpty) {
        final List<dynamic> catList = jsonDecode(customCatsStr);
        final customCats = catList.map((e) => RoutineCategory.fromJson(e)).toList();
        allCategories = [...defaultCategories, ...customCats];
      } else {
        allCategories = List.from(defaultCategories);
      }

      // Load routine entries
      final entriesStr = prefs.getString(_kEntriesKey);
      if (entriesStr != null && entriesStr.isNotEmpty) {
        final List<dynamic> entryList = jsonDecode(entriesStr);
        cachedEntries = entryList.map((e) => RoutineEntry.fromJson(e)).toList();
        cachedEntries.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (_) {}
  }

  /// Save cached entries to local storage
  static Future<void> _persistEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(cachedEntries.map((e) => e.toJson()).toList());
      await prefs.setString(_kEntriesKey, str);
      dataVersion.value++;
    } catch (_) {}
  }

  /// Save custom categories to local storage
  static Future<void> _persistCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customOnly = allCategories.where((c) => c.isCustom).map((c) => c.toJson()).toList();
      await prefs.setString(_kCustomCategoriesKey, jsonEncode(customOnly));
      dataVersion.value++;
    } catch (_) {}
  }

  /// Add a new work log entry
  static Future<RoutineEntry> addEntry({
    required String title,
    required String categoryId,
    required String categoryName,
    required DateTime date,
    String? time,
    String? notes,
    double? hoursSpent,
    double? expense,
    bool isCompleted = true,
  }) async {
    final newEntry = RoutineEntry(
      id: generateUuidV4(),
      title: title.trim(),
      categoryId: categoryId,
      categoryName: categoryName,
      date: date,
      time: time,
      notes: notes?.trim(),
      hoursSpent: hoursSpent,
      expense: expense,
      isCompleted: isCompleted,
      createdAt: DateTime.now(),
    );

    cachedEntries.insert(0, newEntry);
    cachedEntries.sort((a, b) => b.date.compareTo(a.date));
    await _persistEntries();
    return newEntry;
  }

  /// Update an existing entry
  static Future<void> updateEntry(RoutineEntry updated) async {
    final idx = cachedEntries.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      cachedEntries[idx] = updated;
      cachedEntries.sort((a, b) => b.date.compareTo(a.date));
      await _persistEntries();
    }
  }

  /// Delete an entry
  static Future<void> deleteEntry(String id) async {
    cachedEntries.removeWhere((e) => e.id == id);
    await _persistEntries();
  }

  /// Add a user-created custom category
  static Future<RoutineCategory> addCustomCategory({
    required String name,
    required int iconCode,
    required String colorHex,
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newCategory = RoutineCategory(
      id: id,
      name: name.trim(),
      iconCode: iconCode,
      colorHex: colorHex,
      isCustom: true,
    );

    allCategories.add(newCategory);
    await _persistCustomCategories();
    return newCategory;
  }

  /// Delete a custom category
  static Future<void> deleteCustomCategory(String id) async {
    allCategories.removeWhere((c) => c.id == id && c.isCustom);
    await _persistCustomCategories();
  }

  /// Helper to get category by ID
  static RoutineCategory getCategory(String id) {
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => RoutineCategory(
        id: id,
        name: 'General',
        iconCode: Icons.task_alt_rounded.codePoint,
        colorHex: '#818CF8',
      ),
    );
  }
}
