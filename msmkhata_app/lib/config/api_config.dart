import 'package:flutter/foundation.dart';

class ApiConfig {
  // Supabase Cloud Credentials
  static const String supabaseUrl = 'https://dzjzinbogydbnatkibuw.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6anppbmJvZ3lkYm5hdGtpYnV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMjIwMDAsImV4cCI6MjEwODU5ODAwMH0.I8DylpQtpCHpKFOUFXgfzALl9T9xA3nKhX6IYOBfbtU';

  // Production Render Backend URL (Localhost removed)
  static const String _defaultRenderBackendUrl = 'https://msmkhata-api.onrender.com/api/v1';

  // Allow build-time override via --dart-define=BACKEND_URL=https://your-custom.onrender.com/api/v1
  static const String _envBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: _defaultRenderBackendUrl,
  );

  // Runtime custom URL override if user changes it in settings
  static String? _runtimeCustomUrl;

  static void setCustomUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _runtimeCustomUrl = null;
    } else {
      String clean = url.trim();
      if (!clean.endsWith('/api/v1')) {
        clean = clean.replaceAll(RegExp(r'/+$'), '') + '/api/v1';
      }
      _runtimeCustomUrl = clean;
    }
  }

  static String get baseUrl {
    if (_runtimeCustomUrl != null && _runtimeCustomUrl!.isNotEmpty) {
      return _runtimeCustomUrl!;
    }
    return _envBackendUrl;
  }

  static String get hostDomain {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (_) {
      return 'msmkhata-api.onrender.com';
    }
  }
}
