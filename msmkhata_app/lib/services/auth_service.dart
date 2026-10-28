import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

import 'desktop_auth_service.dart';
import 'sync_service.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Currently logged in Supabase user
  static User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Current session
  static Session? get currentSession {
    try {
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Auth state changes stream (login, logout, token refresh)
  static Stream<AuthState> get onAuthStateChange {
    try {
      return _client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Whether user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Unique Supabase User UUID
  static String? get currentUserId => currentUser?.id;

  /// User display name
  static String get displayName {
    final user = currentUser;
    if (user == null) return 'Guest';
    final meta = user.userMetadata ?? {};
    return meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User';
  }

  /// User email
  static String get email => currentUser?.email ?? '';

  /// User avatar image URL
  static String? get avatarUrl {
    final meta = currentUser?.userMetadata ?? {};
    return meta['avatar_url'] ?? meta['picture'];
  }

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<String> _getRedirectUrl() async {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    if (_isDesktop) {
      try {
        final port = await DesktopLoopbackAuth.start();
        return 'http://localhost:$port';
      } catch (e) {
        debugPrint('Loopback start notice: $e');
      }
    }
    return 'io.supabase.msmkhata://login-callback/';
  }

  /// Sign in with Google (Uses 100% native Google Play Services bottom-sheet on Android; loopback auto-close on Desktop; Web OAuth)
  static Future<void> signInWithGoogle() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final googleSignIn = GoogleSignIn(
            clientId: ApiConfig.googleAndroidClientId,
            serverClientId: ApiConfig.googleWebClientId,
            scopes: ['email', 'profile'],
          );
          final googleUser = await googleSignIn.signIn();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final idToken = googleAuth.idToken;
            if (idToken != null && idToken.isNotEmpty) {
              await _client.auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: idToken,
                accessToken: googleAuth.accessToken,
              );
              return;
            } else {
              throw Exception('Google Play Services returned null ID token. Ensure Android Client ID is registered in Google Cloud Console.');
            }
          } else {
            // User cancelled or tapped outside the native account picker bottom sheet
            debugPrint('User cancelled native Google Sign-In bottom sheet.');
            return;
          }
        } catch (nativeErr) {
          debugPrint('Native Google Sign-In error: $nativeErr');
          rethrow;
        }
      }

      final redirect = await _getRedirectUrl();
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign in with GitHub OAuth
  static Future<void> signInWithGitHub() async {
    try {
      final redirect = await _getRedirectUrl();
      await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: redirect,
      );
    } catch (e) {
      debugPrint('GitHub Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign in with Email and Password (100% In-App, Zero Browser, Zero xdg-open)
  static Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      rethrow;
    }
  }

  /// Create Account with Email and Password (100% In-App)
  static Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: fullName != null && fullName.trim().isNotEmpty
            ? {'full_name': fullName.trim()}
            : null,
      );
    } catch (e) {
      debugPrint('Email Sign-Up Error: $e');
      rethrow;
    }
  }

  /// Handle callback URL manually (Useful on Linux/Windows Desktop when xdg-open prompt is cancelled or unhandled)
  static Future<void> handleManualCallbackUrl(String url) async {
    try {
      final cleanUrl = url.trim();
      final uri = Uri.parse(cleanUrl);
      await _client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('Manual URL login error: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign-Out Error: $e');
    }
  }

  /// Completely wipe local Supabase session, shared preferences, and cached tokens
  static Future<void> clearAllLocalDataAndSession() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out notice during clean purge: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await SyncService.clearCache();
      debugPrint('Cleaned all local shared preferences and sync cache successfully.');
    } catch (e) {
      debugPrint('Error clearing local shared preferences: $e');
    }
  }
}
