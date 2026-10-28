import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _heartbeatTimer;

  /// ValueNotifier indicating whether the device has active internet
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// ValueNotifier indicating whether a connectivity check is currently in progress
  final ValueNotifier<bool> isChecking = ValueNotifier<bool>(false);

  /// Callback when status changes (e.g. for showing snackbars)
  Function(bool isConnected)? onStatusChanged;

  bool _initialized = false;

  void initialize({Function(bool isConnected)? onStatusChanged}) {
    if (_initialized) return;
    _initialized = true;
    this.onStatusChanged = onStatusChanged;

    // Listen to OS-level connectivity changes (WiFi, Cellular, Ethernet, None)
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluateConnectivity(results);
    });

    // Initial check
    checkConnectivity();

    // Periodic heartbeat check every 25 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      checkActualInternet();
    });
  }

  Future<void> _evaluateConnectivity(List<ConnectivityResult> results) async {
    // If OS reports completely disconnected
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _updateStatus(false);
      return;
    }

    // OS reports connected to a network adapter -> verify real internet access
    await checkActualInternet();
  }

  /// Probes the internet by attempting a quick request to backend health or google
  Future<bool> checkActualInternet() async {
    isChecking.value = true;
    bool connected = false;

    try {
      // 1. Try FastAPI backend health check first
      final backendUri = Uri.parse(ApiConfig.baseUrl.replaceAll('/api/v1', '') + '/health');
      final res = await http.get(backendUri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        connected = true;
      }
    } catch (_) {
      // If backend is waking up or failed, check standard internet access via Cloudflare / Google
      try {
        final res = await http.head(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 3));
        if (res.statusCode >= 200 && res.statusCode < 400) {
          connected = true;
        }
      } catch (_) {
        try {
          final res = await http.head(Uri.parse('https://1.1.1.1')).timeout(const Duration(seconds: 3));
          if (res.statusCode >= 200 && res.statusCode < 400) {
            connected = true;
          }
        } catch (_) {
          connected = false;
        }
      }
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
    _heartbeatTimer?.cancel();
  }
}
