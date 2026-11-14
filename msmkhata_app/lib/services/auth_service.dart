import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

import 'desktop_auth_service.dart';
import 'sync_service.dart';
import 'grocery_service.dart';
import 'routine_service.dart';
import 'account_service.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _kIsLoggedInKey = 'msm_auth_is_logged_in';
  static const String _kCachedUserIdKey = 'msm_auth_user_id';
  static const String _kCachedUserEmailKey = 'msm_auth_user_email';
  static const String _kCachedUserNameKey = 'msm_auth_user_name';
  static const String _kCachedAvatarUrlKey = 'msm_auth_avatar_url';

  static bool isPersistentLoggedIn = false;
  static String? cachedUserId;
  static String? cachedUserEmail;
  static String? cachedDisplayName;
  static String? cachedAvatarUrl;

  static bool _initialized = false;

  /// Initialize and restore persistent authentication state
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      isPersistentLoggedIn = prefs.getBool(_kIsLoggedInKey) ?? false;
      cachedUserId = prefs.getString(_kCachedUserIdKey);
      cachedUserEmail = prefs.getString(_kCachedUserEmailKey);
      cachedDisplayName = prefs.getString(_kCachedUserNameKey);
      cachedAvatarUrl = prefs.getString(_kCachedAvatarUrlKey);

      // Check current Supabase session on startup
      final session = currentSession;
      if (session != null) {
        isPersistentLoggedIn = true;
        cachedUserId = session.user.id;
        cachedUserEmail = session.user.email;
        final meta = session.user.userMetadata ?? {};
        cachedDisplayName = meta['full_name'] ?? meta['name'] ?? session.user.email?.split('@').first;
        cachedAvatarUrl = meta['avatar_url'] ?? meta['picture'];
        await _saveLoginState(prefs);
      }

      // Listen to Supabase auth events
      _client.auth.onAuthStateChange.listen((data) async {
        final s = data.session;
        if (data.event == AuthChangeEvent.signedOut) {
          isPersistentLoggedIn = false;
          cachedUserId = null;
          cachedUserEmail = null;
          cachedDisplayName = null;
          cachedAvatarUrl = null;
          try {
            final p = await SharedPreferences.getInstance();
            await p.remove(_kIsLoggedInKey);
            await p.remove(_kCachedUserIdKey);
            await p.remove(_kCachedUserEmailKey);
            await p.remove(_kCachedUserNameKey);
            await p.remove(_kCachedAvatarUrlKey);
            await clearGoogleAccessToken();
          } catch (_) {}

          // Master Purge on signedOut event
          try {
            await SyncService.clearCache();
            await GroceryService.clearAllData();
            await RoutineService.clearAllData();
            await AccountService.resetToDefault();
          } catch (_) {}
        } else if (s != null) {
          isPersistentLoggedIn = true;
          cachedUserId = s.user.id;
          cachedUserEmail = s.user.email;
          final meta = s.user.userMetadata ?? {};
          cachedDisplayName = meta['full_name'] ?? meta['name'] ?? s.user.email?.split('@').first;
          cachedAvatarUrl = meta['avatar_url'] ?? meta['picture'];
          if (s.providerToken != null && s.providerToken!.isNotEmpty) {
            await saveGoogleAccessToken(s.providerToken!);
          }
          final p = await SharedPreferences.getInstance();
          await _saveLoginState(p);

          // User session detected: initialize and load fresh cloud data
          SyncService.syncAll(forceFull: true);
          GroceryService.fetchStores();
          RoutineService.fetchEntries();
          RoutineService.fetchCategories();
        }
      });

      // Silently refresh expired session without kicking user out
      ensureSessionRefreshed();
    } catch (e) {
      debugPrint('AuthService init notice: $e');
    }
  }

  static Future<void> _saveLoginState(SharedPreferences p) async {
    try {
      await p.setBool(_kIsLoggedInKey, true);
      if (cachedUserId != null) await p.setString(_kCachedUserIdKey, cachedUserId!);
      if (cachedUserEmail != null) await p.setString(_kCachedUserEmailKey, cachedUserEmail!);
      if (cachedDisplayName != null) await p.setString(_kCachedUserNameKey, cachedDisplayName!);
      if (cachedAvatarUrl != null) await p.setString(_kCachedAvatarUrlKey, cachedAvatarUrl!);
    } catch (_) {}
  }

  /// Silently refresh the session without logging out or interrupting the user
  static Future<void> ensureSessionRefreshed() async {
    if (!isPersistentLoggedIn) return;
    try {
      final session = currentSession;
      if (session == null || session.isExpired) {
        debugPrint('Refreshing Supabase session in background...');
        await _client.auth.refreshSession();
        debugPrint('Session refreshed successfully.');
      }
    } catch (e) {
      debugPrint('Background session refresh notice: $e');
      // NEVER log out or set isPersistentLoggedIn = false on network failure!
    }
  }

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
  static bool get isAuthenticated => currentUser != null || isPersistentLoggedIn;

  /// Unique Supabase User UUID
  static String? get currentUserId => currentUser?.id ?? cachedUserId;

  /// User display name
  static String get displayName {
    final user = currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      return meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User';
    }
    return cachedDisplayName ?? 'User';
  }

  /// User email
  static String get email => currentUser?.email ?? cachedUserEmail ?? '';

  /// Primary administrator email
  static const String primaryAdminEmail = 'mohdsalman4151@gmail.com';

  /// Whether current logged-in user possesses administrator privileges
  static bool get isAdmin => email.trim().toLowerCase() == primaryAdminEmail;

  /// User avatar image URL
  static String? get avatarUrl {
    final meta = currentUser?.userMetadata ?? {};
    return meta['avatar_url'] ?? meta['picture'] ?? cachedAvatarUrl;
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

  /// Save Google access token for Drive backup
  static Future<void> saveGoogleAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_drive_access_token', token);
  }

  /// Clear stored Google Drive access token (e.g. when scope is insufficient)
  static Future<void> clearGoogleAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_drive_access_token');
  }

  /// Retrieve Google access token
  static Future<String?> getGoogleAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('google_drive_access_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      if (savedToken.startsWith('eyJ')) {
        await prefs.remove('google_drive_access_token');
      } else {
        return savedToken;
      }
    }
    final token = currentSession?.providerToken;
    if (token != null && token.isNotEmpty && !token.startsWith('eyJ')) {
      return token;
    }
    return null;
  }

  /// Sign in with Google (Uses 100% native Google Play Services bottom-sheet on Android; loopback auto-close on Desktop; Web OAuth)
  static Future<void> signInWithGoogle() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final googleSignIn = GoogleSignIn(
            clientId: ApiConfig.googleAndroidClientId,
            serverClientId: ApiConfig.googleWebClientId,
            scopes: [
              'email',
              'profile',
              'https://www.googleapis.com/auth/drive.file',
            ],
          );
          final googleUser = await googleSignIn.signIn();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final idToken = googleAuth.idToken;
            if (idToken != null && idToken.isNotEmpty) {
              if (googleAuth.accessToken != null && googleAuth.accessToken!.isNotEmpty) {
                await saveGoogleAccessToken(googleAuth.accessToken!);
              }
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
        scopes: 'https://www.googleapis.com/auth/drive.file',
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Explicitly authorize Google Drive scope for cloud backup
  static Future<String?> authorizeGoogleDrive() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final googleSignIn = GoogleSignIn(
          clientId: ApiConfig.googleAndroidClientId,
          serverClientId: ApiConfig.googleWebClientId,
          scopes: [
            'email',
            'profile',
            'https://www.googleapis.com/auth/drive.file',
          ],
        );
        final googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final token = googleAuth.accessToken;
          if (token != null && token.isNotEmpty) {
            await saveGoogleAccessToken(token);
            return token;
          }
        }
        return null;
      }

      if (_isDesktop) {
        final port = await DesktopLoopbackAuth.start();
        final redirect = 'http://localhost:$port';

        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirect,
          scopes: 'https://www.googleapis.com/auth/drive.file',
          queryParams: {'access_type': 'offline', 'prompt': 'consent'},
        );

        // Await loopback server to capture authorization credentials from the browser
        final token = await DesktopLoopbackAuth.waitForAuth(timeout: const Duration(minutes: 3));
        if (token != null && token.isNotEmpty) {
          await saveGoogleAccessToken(token);
          return token;
        }

        final saved = await getGoogleAccessToken();
        if (saved != null && saved.isNotEmpty) return saved;
        return null;
      }

      final redirect = await _getRedirectUrl();
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
        scopes: 'https://www.googleapis.com/auth/drive.file',
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
      );
      return await getGoogleAccessToken();
    } catch (e) {
      debugPrint('Google Drive Authorization Error: $e');
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
      final redirect = await _getRedirectUrl();
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: redirect,
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

  /// Sign out & Master Data Purge (Guarantee 100% clean multi-user isolation)
  static Future<void> signOut() async {
    isPersistentLoggedIn = false;
    cachedUserId = null;
    cachedUserEmail = null;
    cachedDisplayName = null;
    cachedAvatarUrl = null;

    // 1. Clear SharedPreferences Auth keys & cached tokens
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsLoggedInKey);
      await prefs.remove(_kCachedUserIdKey);
      await prefs.remove(_kCachedUserEmailKey);
      await prefs.remove(_kCachedUserNameKey);
      await prefs.remove(_kCachedAvatarUrlKey);
      await clearGoogleAccessToken();
    } catch (_) {}

    // 2. Wipe Main Ledger Transactions, Stats, Persons & Pending Queues
    try {
      await SyncService.clearCache();
    } catch (e) {
      debugPrint('SyncService wipe error: $e');
    }

    // 3. Wipe Grocery Dukaan Khata Memory & Disk State
    try {
      await GroceryService.clearAllData();
    } catch (e) {
      debugPrint('GroceryService wipe error: $e');
    }

    // 4. Wipe Daily Routine Work Diary Memory & Disk State
    try {
      await RoutineService.clearAllData();
    } catch (e) {
      debugPrint('RoutineService wipe error: $e');
    }

    // 5. Reset Custom Account Books to Default Primary Book
    try {
      await AccountService.resetToDefault();
    } catch (e) {
      debugPrint('AccountService reset error: $e');
    }

    // 6. Supabase Session Termination
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
