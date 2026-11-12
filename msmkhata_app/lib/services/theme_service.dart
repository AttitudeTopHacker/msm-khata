import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'budget_service.dart';

/// Preset palette for card borders, highlights, and glowing neon accents
class AppAccentTheme {
  final String id;
  final String name;
  final Color primary;
  final Color light;
  final Color glow;
  final Color cardBorder;
  final Color cardBg;

  const AppAccentTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.light,
    required this.glow,
    required this.cardBorder,
    required this.cardBg,
  });
}

/// Reactive Theme & Personalization Service for MsmKhata
class ThemeService {
  static const String _kAccentKey = 'msm_theme_accent_id';
  static const String _kHideBalanceKey = 'msm_privacy_hide_balance';

  static final List<AppAccentTheme> availableAccents = [
    const AppAccentTheme(
      id: 'indigo',
      name: 'Royal Indigo',
      primary: Color(0xFF4F46E5),
      light: Color(0xFF818CF8),
      glow: Color(0xFF6366F1),
      cardBorder: Color(0x666366F1),
      cardBg: Color(0xFF1E293B),
    ),
    const AppAccentTheme(
      id: 'emerald',
      name: 'Emerald Mint',
      primary: Color(0xFF10B981),
      light: Color(0xFF34D399),
      glow: Color(0xFF059669),
      cardBorder: Color(0x6610B981),
      cardBg: Color(0xFF0F291E),
    ),
    const AppAccentTheme(
      id: 'purple',
      name: 'Cyber Purple',
      primary: Color(0xFF8B5CF6),
      light: Color(0xFFC084FC),
      glow: Color(0xFF7C3AED),
      cardBorder: Color(0x668B5CF6),
      cardBg: Color(0xFF231834),
    ),
    const AppAccentTheme(
      id: 'amber',
      name: 'Sunset Amber',
      primary: Color(0xFFF59E0B),
      light: Color(0xFFFCD34D),
      glow: Color(0xFFD97706),
      cardBorder: Color(0x66F59E0B),
      cardBg: Color(0xFF2A2010),
    ),
    const AppAccentTheme(
      id: 'rose',
      name: 'Crimson Rose',
      primary: Color(0xFFF43F5E),
      light: Color(0xFFFB7185),
      glow: Color(0xFFE11D48),
      cardBorder: Color(0x66F43F5E),
      cardBg: Color(0xFF2A141A),
    ),
    const AppAccentTheme(
      id: 'cyan',
      name: 'Ocean Cyan',
      primary: Color(0xFF06B6D4),
      light: Color(0xFF38BDF8),
      glow: Color(0xFF0891B2),
      cardBorder: Color(0x6606B6D4),
      cardBg: Color(0xFF102632),
    ),
  ];

  static final ValueNotifier<AppAccentTheme> accentNotifier =
      ValueNotifier<AppAccentTheme>(availableAccents[0]);

  static final ValueNotifier<bool> hideBalanceNotifier =
      ValueNotifier<bool>(false);

  static bool _initialized = false;

  /// Initialize and load saved theme preferences on startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kAccentKey) ?? 'indigo';
      final match = availableAccents.firstWhere(
        (a) => a.id == savedId,
        orElse: () => availableAccents[0],
      );
      accentNotifier.value = match;

      final savedHideBalance = prefs.getBool(_kHideBalanceKey) ?? prefs.getBool('msm_private_mode_enabled') ?? false;
      hideBalanceNotifier.value = savedHideBalance;
      BudgetService.privateModeNotifier.value = savedHideBalance;
    } catch (_) {}
  }

  static Future<void> setAccent(String id) async {
    final match = availableAccents.firstWhere(
      (a) => a.id == id,
      orElse: () => availableAccents[0],
    );
    accentNotifier.value = match;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccentKey, id);
    } catch (_) {}
  }

  static Future<void> toggleHideBalance(bool value) async {
    hideBalanceNotifier.value = value;
    BudgetService.privateModeNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHideBalanceKey, value);
      await prefs.setBool('msm_private_mode_enabled', value);
    } catch (_) {}
  }

  static AppAccentTheme get current => accentNotifier.value;
  static bool get isBalanceHidden => hideBalanceNotifier.value;

  /// Formats currency text with privacy masking when enabled:
  /// e.g. '₹ 1,50,000' -> '₹ ••••••'
  static String formatAmount(String rawFormatted) {
    if (isBalanceHidden) {
      return '₹ ••••••';
    }
    return rawFormatted;
  }
}
