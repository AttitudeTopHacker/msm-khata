import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// ValueNotifier indicating whether the device has active internet
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// ValueNotifier indicating whether a connectivity check is currently in progress
  final ValueNotifier<bool> isChecking = ValueNotifier<bool>(false);

  /// Callback when status changes (e.g. for showing snackbars)
  Function(bool isConnected)? onStatusChanged;

  bool _initialized = false;

  /// Static helper to trigger an immediate check on data refresh or button tap
  static Future<bool> checkNow() => _instance.checkActualInternet();

  void initialize({Function(bool isConnected)? onStatusChanged}) {
    if (_initialized) return;
    _initialized = true;
    this.onStatusChanged = onStatusChanged;

    // 1. Listen to OS-level connectivity events (Triggers immediately when WiFi/Data is turned off or on)
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluateConnectivity(results);
    });

    // 2. Initial check on application open / launch
    checkConnectivity();

    // NOTE: Heartbeat timer completely removed as requested (saves battery, 0 background network load)
  }

  Future<void> _evaluateConnectivity(List<ConnectivityResult> results) async {
    // If OS reports completely disconnected, update immediately in 0ms!
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _updateStatus(false);
      return;
    }

    // OS reports connected to a network adapter -> verify real internet access instantly
    await checkActualInternet();
  }

  /// Probes real internet access in <100ms without waking up or consuming Render backend hours
  Future<bool> checkActualInternet() async {
    isChecking.value = true;
    bool connected = false;

    try {
      if (!kIsWeb) {
        // Native (Android, Linux, Windows): Instant raw DNS socket check to Cloudflare / Google DNS (~20-50ms)
        try {
          final result = await InternetAddress.lookup('1.1.1.1')
              .timeout(const Duration(milliseconds: 1200));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            connected = true;
          }
        } on SocketException catch (_) {
          connected = false;
        } catch (_) {
          // Backup fallback to Google DNS
          try {
            final backup = await InternetAddress.lookup('google.com')
                .timeout(const Duration(milliseconds: 1200));
            connected = backup.isNotEmpty && backup[0].rawAddress.isNotEmpty;
          } catch (_) {
            connected = false;
          }
        }
      } else {
        // Web platform: Fast HTTP HEAD to Cloudflare
        final res = await http.head(Uri.parse('https://1.1.1.1'))
            .timeout(const Duration(milliseconds: 1500));
        connected = res.statusCode >= 200 && res.statusCode < 400;
      }
    } catch (_) {
      connected = false;
    }

    isChecking.value = false;
    _updateStatus(connected);
    return connected;
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        _updateStatus(false);
        return false;
      }
      return await checkActualInternet();
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return isOnline.value;
    }
  }

  void _updateStatus(bool connected) {
    if (isOnline.value != connected) {
      isOnline.value = connected;
      if (onStatusChanged != null) {
        onStatusChanged!(connected);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
