import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Enterprise Security & Privacy Service for MsmKhata (MPIN & Biometric Unlock)
class SecurityService {
  static const String _kPinHashKey = 'msm_sec_pin_hash';
  static const String _kPinEnabledKey = 'msm_sec_pin_enabled';
  static const String _kBiometricEnabledKey = 'msm_sec_biometric_enabled';
  static const String _kSalt = 'msm_khata_2026_salt_sec_';

  static final ValueNotifier<bool> isPinEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isBiometricEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isAppLockedNotifier = ValueNotifier<bool>(false);

  static String? _cachedPinHash;
  static bool _initialized = false;

  /// Initialize security state on app startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPinHash = prefs.getString(_kPinHashKey);
      final pinEnabled = prefs.getBool(_kPinEnabledKey) ?? false;
      final bioEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;

      isPinEnabledNotifier.value = pinEnabled && _cachedPinHash != null;
      isBiometricEnabledNotifier.value = bioEnabled;

      // Lock app initially if user has PIN security enabled
      if (isPinEnabledNotifier.value) {
        isAppLockedNotifier.value = true;
      }
    } catch (_) {}
  }

  static bool get hasPin => _cachedPinHash != null && _cachedPinHash!.isNotEmpty;
  static bool get isPinEnabled => isPinEnabledNotifier.value;
  static bool get isBiometricEnabled => isBiometricEnabledNotifier.value;
  static bool get isAppLocked => isAppLockedNotifier.value;

  static String _hashPin(String pin) {
    final bytes = utf8.encode('$_kSalt$pin');
    return sha256.convert(bytes).toString();
  }

  static Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    _cachedPinHash = hash;
    isPinEnabledNotifier.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPinHashKey, hash);
      await prefs.setBool(_kPinEnabledKey, true);
    } catch (_) {}
  }

  static Future<void> removePin() async {
    _cachedPinHash = null;
    isPinEnabledNotifier.value = false;
    isBiometricEnabledNotifier.value = false;
    isAppLockedNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPinHashKey);
      await prefs.setBool(_kPinEnabledKey, false);
      await prefs.setBool(_kBiometricEnabledKey, false);
    } catch (_) {}
  }

  static bool verifyPin(String inputPin) {
    if (_cachedPinHash == null) return true;
    final inputHash = _hashPin(inputPin);
    final isValid = inputHash == _cachedPinHash;
    if (isValid) {
      isAppLockedNotifier.value = false;
    }
    return isValid;
  }

  static Future<void> togglePinEnabled(bool enabled) async {
    if (enabled && !hasPin) return;
    isPinEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPinEnabledKey, enabled);
    } catch (_) {}
  }

  static Future<void> toggleBiometric(bool enabled) async {
    isBiometricEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBiometricEnabledKey, enabled);
    } catch (_) {}
  }

  static void unlockApp() {
    isAppLockedNotifier.value = false;
  }

  static void lockApp() {
    if (isPinEnabled) {
      isAppLockedNotifier.value = true;
    }
  }
}
