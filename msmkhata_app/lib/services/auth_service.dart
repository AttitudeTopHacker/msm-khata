import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static String get _redirectUrl {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'io.supabase.msmkhata://login-callback/';
  }

  /// Sign in with Google OAuth (Tries native Google Play Services bottom-sheet on Android, falls back to OAuth)
  static Future<void> signInWithGoogle() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final googleSignIn = GoogleSignIn(
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
            }
          }
        } catch (nativeErr) {
          debugPrint('Native Google Sign-In notice: $nativeErr (Falling back to Web OAuth)');
        }
      }

      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign in with GitHub OAuth
  static Future<void> signInWithGitHub() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: _redirectUrl,
      );
    } catch (e) {
      debugPrint('GitHub Sign-In Error: $e');
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
}
