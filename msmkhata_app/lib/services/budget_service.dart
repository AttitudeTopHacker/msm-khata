import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage Personal Pocket Budget targets and Privacy Mode for MsmKhata.
class BudgetService {
  static const String _kMonthlyBudgetKey = 'msm_monthly_budget_target';
  static const String _kPrivateModeKey = 'msm_private_mode_enabled';
  static const String _kDashboardModeKey = 'msm_active_dashboard_mode';

  // Default monthly budget: ₹25,000
  static const double defaultMonthlyBudget = 25000.0;

  // Reactive state notifiers
  static final ValueNotifier<double> monthlyBudgetNotifier = ValueNotifier<double>(defaultMonthlyBudget);
  static final ValueNotifier<bool> privateModeNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<int> dashboardModeNotifier = ValueNotifier<int>(0); // 0 = Len-Den, 1 = Personal Pocket

  static bool _initialized = false;

  /// Initialize persistent budget and privacy preferences
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBudget = prefs.getDouble(_kMonthlyBudgetKey);
      if (savedBudget != null && savedBudget > 0) {
        monthlyBudgetNotifier.value = savedBudget;
      }

      final savedPrivate = prefs.getBool(_kPrivateModeKey);
      if (savedPrivate != null) {
        privateModeNotifier.value = savedPrivate;
      }

      final savedMode = prefs.getInt(_kDashboardModeKey);
      if (savedMode != null && (savedMode == 0 || savedMode == 1)) {
        dashboardModeNotifier.value = savedMode;
      }
    } catch (e) {
      debugPrint('BudgetService init error: $e');
    }
  }

  /// Update and persist monthly budget target
  static Future<void> setMonthlyBudget(double amount) async {
    if (amount <= 0) return;
    monthlyBudgetNotifier.value = amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kMonthlyBudgetKey, amount);
    } catch (e) {
      debugPrint('Error saving monthly budget: $e');
    }
  }

  /// Toggle privacy mode on/off
  static Future<void> togglePrivateMode() async {
    final next = !privateModeNotifier.value;
    privateModeNotifier.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrivateModeKey, next);
    } catch (e) {
      debugPrint('Error saving private mode: $e');
    }
  }

  /// Switch active dashboard view (0 = Len-Den, 1 = Personal Pocket)
  static Future<void> setDashboardMode(int mode) async {
    if (mode != 0 && mode != 1) return;
    dashboardModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDashboardModeKey, mode);
    } catch (e) {
      debugPrint('Error saving dashboard mode: $e');
    }
  }

  /// Helper to format or mask text when privacy mode is active
  static String maskIfPrivate(String visibleText, {bool isPrivate = false}) {
    if (isPrivate || privateModeNotifier.value) {
      return '••••••';
    }
    return visibleText;
  }
}
