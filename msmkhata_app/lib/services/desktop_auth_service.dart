import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure Local Loopback Authentication Server for Desktop Platforms (Linux & Windows).
///
/// Implements RFC 8252 (OAuth 2.0 for Native Apps):
/// - Binds strictly to 127.0.0.1 (IPv4 loopback only; zero external network exposure).
/// - Automatically serves a sleek dark-themed HTML confirmation page.
/// - Closes the Chrome browser tab automatically via JavaScript after capturing credentials.
/// - Safely stops the server immediately after authorization completes.
class DesktopLoopbackAuth {
  static HttpServer? _server;
  static int? _port;

  static int? get port => _port;
  static bool get isRunning => _server != null;

  /// Start the loopback listener on port 3000 (pre-registered in Supabase), with fallback to any available port
  static Future<int> start() async {
    await stop();

    // Prefer port 3000 as it is pre-configured in Supabase OAuth redirect URLs
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      _port = 3000;
    } catch (_) {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 54321);
        _port = 54321;
      } catch (_) {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _port = _server!.port;
      }
    }

    debugPrint('Desktop Loopback Auth Server listening securely on 127.0.0.1:$_port');

    _server!.listen((HttpRequest request) async {
      final uri = request.uri;
      final response = request.response;

      // Enable CORS for localhost callback
      response.headers.add('Access-Control-Allow-Origin', '*');
      response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.ok;
        await response.close();
        return;
      }

      // Handle token payload submitted by client-side JavaScript from browser URL fragment
      if (request.method == 'POST' && (uri.path == '/token' || uri.path == '/api/token')) {
        try {
          final content = await utf8.decoder.bind(request).join();
          final data = jsonDecode(content);
          final rawUrl = data['url']?.toString();

          if (rawUrl != null && rawUrl.isNotEmpty) {
            debugPrint('Received OAuth callback payload via loopback: $rawUrl');
            try {
              final uriParsed = Uri.parse(rawUrl.replaceFirst('#', '?'));
              final providerToken = uriParsed.queryParameters['provider_token'];
              if (providerToken != null && providerToken.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('google_drive_access_token', providerToken);
              }
            } catch (_) {}
            await Supabase.instance.client.auth.getSessionFromUrl(Uri.parse(rawUrl));
          }
        } catch (e) {
          debugPrint('Loopback token parse error: $e');
        }

        response.statusCode = HttpStatus.ok;
        response.headers.contentType = ContentType.json;
        response.write('{"status":"authenticated"}');
        await response.close();

        // Gracefully stop loopback server after 800ms
        Future.delayed(const Duration(milliseconds: 800), stop);
        return;
      }

      // If auth code is passed in query parameters (PKCE flow)
      if (uri.queryParameters.containsKey('code') || uri.queryParameters.containsKey('access_token')) {
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
        } catch (e) {
          debugPrint('Loopback query session error: $e');
        }
      }

      // Serve sleek dark-themed confirmation HTML with auto-close script
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.html;
      response.write(_buildAutoCloseHtml());
      await response.close();
    });

    return _port!;
  }

  /// Stop and release the loopback listener
  static Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = null;
  }

  /// Dark-mode auto-closing HTML response
  static String _buildAutoCloseHtml() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MsmKhata — Login Successful</title>
  <style>
    * { box-sizing: border-box; }
    body {
      background: radial-gradient(circle at top, #1E293B, #0F172A);
      color: #F8FAFC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background: #1E293B;
      padding: 40px 48px;
      border-radius: 28px;
      border: 1px solid #334155;
      text-align: center;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 40px rgba(79, 70, 229, 0.15);
      max-width: 440px;
      width: 100%;
      animation: fadeIn 0.4s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(16px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .icon-wrapper {
      width: 72px;
      height: 72px;
      background: rgba(16, 185, 129, 0.15);
      border: 2px solid #10B981;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 18px auto;
      font-size: 36px;
    }
    h1 {
      margin: 0 0 8px 0;
      color: #F8FAFC;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .tag {
      display: inline-flex;
      align-items: center;
      background: rgba(99, 102, 241, 0.15);
      color: #A5B4FC;
      border: 1px solid rgba(99, 102, 241, 0.4);
      padding: 4px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 18px;
    }
    p {
      color: #94A3B8;
      font-size: 14px;
      line-height: 1.55;
      margin: 0 0 24px 0;
    }
    .status-box {
      background: #0F172A;
      border-radius: 14px;
      padding: 12px 16px;
      border: 1px solid #334155;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      font-size: 13px;
      color: #38BDF8;
      font-weight: 600;
    }
    .spinner {
      width: 16px;
      height: 16px;
      border: 2px solid #38BDF8;
      border-top-color: transparent;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .btn-return {
      margin-top: 20px;
      background: #4F46E5;
      color: white;
      border: none;
      padding: 10px 24px;
      border-radius: 12px;
      font-weight: bold;
      font-size: 13px;
      cursor: pointer;
      display: inline-block;
      text-decoration: none;
      transition: background 0.2s;
    }
    .btn-return:hover { background: #4338CA; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-wrapper">✓</div>
    <h1>Login Successful!</h1>
    <div class="tag">MsmKhata Connected</div>
    <p>Aapka account MsmKhata desktop application ke sath safely authenticate ho gaya hai.</p>
    
    <div class="status-box">
      <div class="spinner"></div>
      <span id="status-text">Closing this tab automatically...</span>
    </div>

    <button class="btn-return" onclick="closeNow()">Return to MsmKhata App</button>
  </div>

  <script>
    // 1. Post authentication fragment back to local loopback server
    var fullUrl = window.location.href;
    if (window.location.hash || window.location.search) {
      fetch('/token', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({url: fullUrl})
      }).catch(function(err) {});
    }

    // 2. Automatically attempt window close
    function closeNow() {
      window.open('', '_self', '');
      window.close();
      document.getElementById('status-text').innerText = 'You can safely close this browser tab.';
    }

    setTimeout(closeNow, 1200);
  </script>
</body>
</html>
''';
  }
}
