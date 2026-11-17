import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Enterprise Security & Privacy Service for MsmKhata (MPIN & Biometric Unlock)
class SecurityService {
  static const String _kPinHashKey = 'msm_sec_pin_hash';
  static const String _kPinEnabledKey = 'msm_sec_pin_enabled';
  static const String _kBiometricEnabledKey = 'msm_sec_biometric_enabled';
  static const String _kSalt = 'msm_khata_2026_salt_sec_';

  static const MethodChannel _biometricChannel =
      MethodChannel('com.msmmovin.msmkhata/biometric');

  static final ValueNotifier<bool> isPinEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isBiometricEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isAppLockedNotifier = ValueNotifier<bool>(false);

  static String? _cachedPinHash;
  static bool _initialized = false;
  static DateTime? _lastUnlockTime;
  static bool isAuthenticatingBiometric = false;
  static bool isExternalAuthInProgress = false;
  static bool isPinSetupInProgress = false;

  /// Initialize security state on app startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPinHash = prefs.getString(_kPinHashKey);
      final hasHash = _cachedPinHash != null && _cachedPinHash!.isNotEmpty;
      final pinEnabled = prefs.getBool(_kPinEnabledKey) ?? hasHash;
      final bioEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;

      isPinEnabledNotifier.value = pinEnabled && hasHash;
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
    _lastUnlockTime = DateTime.now();
    isAppLockedNotifier.value = false;
  }

  static void lockApp() {
    if (isExternalAuthInProgress) return;
    if (isAuthenticatingBiometric) return;
    if (isPinSetupInProgress) return;
    if (_lastUnlockTime != null &&
        DateTime.now().difference(_lastUnlockTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    if (isPinEnabled || hasPin) {
      isAppLockedNotifier.value = true;
    }
  }

  /// Check whether device hardware supports biometric (Fingerprint / Face)
  static Future<bool> isBiometricHardwareAvailable() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      final bool? available =
          await _biometricChannel.invokeMethod<bool>('canAuthenticate');
      return available ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger native mobile biometric prompt (Fingerprint scan)
  static Future<bool> authenticateWithBiometric({
    String title = 'MsmKhata Unlock',
    String subtitle = 'Scan fingerprint to unlock application',
  }) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      isAuthenticatingBiometric = true;
      final bool? success = await _biometricChannel.invokeMethod<bool>(
        'authenticate',
        {
          'title': title,
          'subtitle': subtitle,
          'negativeButton': 'Use MPIN',
        },
      );
      if (success == true) {
        unlockApp();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        isAuthenticatingBiometric = false;
      });
    }
  }
}

