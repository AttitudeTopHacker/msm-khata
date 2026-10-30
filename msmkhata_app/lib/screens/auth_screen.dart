import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/msm_shimmer_text.dart';
import '../widgets/oauth_waiting_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _loadingProvider; // 'google', 'github', or null
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSub;

  // In-App Email / Password Direct Auth
  int _authTabIndex = 0; // 0 = Google / Social, 1 = Email & Password
  bool _isSignUpMode = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isEmailLoading = false;

  late final bool _wasInitiallyAuthenticated;

  @override
  void initState() {
    super.initState();
    _wasInitiallyAuthenticated = AuthService.isAuthenticated;
    _authSub = AuthService.onAuthStateChange.listen((data) {
      // ONLY auto-dismiss if user was unauthenticated and now completed sign-in!
      if (!_wasInitiallyAuthenticated &&
          data.event == AuthChangeEvent.signedIn &&
          data.session != null &&
          mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }



  void _handleGoogleSignIn() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      await OAuthWaitingDialog.show(context, provider: 'google');
      return;
    }

    setState(() {
      _loadingProvider = 'google';
      _errorMessage = null;
    });

    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _formatErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  void _handleGitHubSignIn() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      await OAuthWaitingDialog.show(context, provider: 'github');
      return;
    }

    setState(() {
      _loadingProvider = 'github';
      _errorMessage = null;
    });

    try {
      await AuthService.signInWithGitHub();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _formatErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  void _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email address and password.');
      return;
    }

    setState(() {
      _isEmailLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUpMode) {
        final res = await AuthService.signUpWithEmailPassword(
          email: email,
          password: pass,
          fullName: _fullNameController.text.trim(),
        );
        if (mounted) {
          if (res.session == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created! Please check your email inbox to confirm registration.'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      } else {
        await AuthService.signInWithEmailPassword(
          email: email,
          password: pass,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _formatErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  void _showPasteUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Row(
          children: const [
            Icon(Icons.link_rounded, color: Color(0xFF818CF8), size: 22),
            SizedBox(width: 10),
            Text(
              'Paste Auth Callback URL',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If your browser showed "Open xdg-open?" or stopped at the redirect screen on Linux/Desktop, copy the URL from your browser address bar and paste it below:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'io.supabase.msmkhata://login-callback/#access_token=...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _loadingProvider = 'google';
                  _errorMessage = null;
                });
                try {
                  await AuthService.handleManualCallbackUrl(text);
                } catch (e) {
                  if (mounted) setState(() => _errorMessage = _formatErrorMessage(e.toString()));
                } finally {
                  if (mounted) setState(() => _loadingProvider = null);
                }
              }
            },
            child: const Text('Complete Sign In'),
          ),
        ],
      ),
    );
  }

  String _formatErrorMessage(String raw) {
    if (raw.contains('10:') || raw.contains('ApiException: 10')) {
      return 'Google Sign-In notice: Android Client ID is not registered in Google Cloud Console. Please add an Android Client ID with package name com.msmmovin.msmkhata_app and your SHA-1 fingerprint.';
    }
    if (raw.contains('provider is not enabled') || raw.contains('validation_failed')) {
      return 'OAuth provider is not enabled yet in your Supabase dashboard. Please enable Google / GitHub in Authentication > Providers.';
    }
    return raw.replaceAll('Exception:', '').replaceAll('AuthException:', '').trim();
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text(
              'Confirm Sign Out',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from your MsmKhata account?\n\nYour ledger entries, contacts, and balances will remain safe and synchronised in your isolated cloud database.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay Signed In', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleSignOut();
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleSignOut() async {
    await AuthService.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          user != null ? 'My Profile' : 'MsmKhata Sign In',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: !canPop,
        actions: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
              tooltip: 'Close & Return to Dashboard',
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: user != null ? _buildProfileView(user) : _buildSignInCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(dynamic user) {
    final avatar = AuthService.avatarUrl;
    final name = AuthService.displayName;
    final email = AuthService.email;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Account Details Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.25),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                email.isNotEmpty ? email : 'Signed in via OAuth',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Cloud Sync Active',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 14),
                        SizedBox(width: 5),
                        MsmShimmerText(
                          text: 'ORG : msm.movin 2022',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Return to Dashboard Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.dashboard_rounded, size: 18),
            label: const Text(
              'Return to Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Sign Out Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSignInCard() {
    final isGoogleLoading = _loadingProvider == 'google';
    final isGitHubLoading = _loadingProvider == 'github';
    final isAnyLoading = _loadingProvider != null;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'MsmKhata',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to access your ledger and financial analytics',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 22),

          // Auth Mode Segment Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _authTabIndex = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _authTabIndex == 0 ? const Color(0xFF4F46E5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: _authTabIndex == 0 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'One-Tap Social',
                            style: TextStyle(
                              color: _authTabIndex == 0 ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: _authTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _authTabIndex = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _authTabIndex == 1 ? const Color(0xFF4F46E5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 15,
                            color: _authTabIndex == 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Email & Pass (In-App)',
                            style: TextStyle(
                              color: _authTabIndex == 1 ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: _authTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Error Message Banner (if any)
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // TAB 0: One-Tap Social (Google Native / GitHub)
          if (_authTabIndex == 0) ...[
            // 1. Continue with Google Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: isAnyLoading ? null : _handleGoogleSignIn,
                child: isGoogleLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF1E293B)),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                color: Color(0xFF4285F4),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                                ? 'Continue with Google (Native)'
                                : 'Continue with Google',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Continue with GitHub Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                  ),
                  elevation: 0,
                ),
                onPressed: isAnyLoading ? null : _handleGitHubSignIn,
                child: isGitHubLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.terminal_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Continue with GitHub',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Desktop manual callback helper
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.linux ||
                    defaultTargetPlatform == TargetPlatform.windows)) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _showPasteUrlDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155).withOpacity(0.7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.link_rounded, size: 14, color: Color(0xFF818CF8)),
                      SizedBox(width: 8),
                      Text(
                        'Desktop helper: Stuck on "Open xdg-open"? Paste URL here',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            // TAB 1: 100% Native In-App Email & Password
            if (_isSignUpMode) ...[
              TextField(
                controller: _fullNameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF818CF8), size: 18),
                  hintText: 'Full Name',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF818CF8), size: 18),
                hintText: 'Email address (e.g. user@gmail.com)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF818CF8), size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                hintText: 'Password (min 6 characters)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isEmailLoading ? null : _handleEmailAuth,
                child: _isEmailLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isSignUpMode ? 'Create Account (In-App)' : 'Sign In with Email',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isSignUpMode = !_isSignUpMode;
                  _errorMessage = null;
                }),
                child: Text(
                  _isSignUpMode
                      ? 'Already have an account? Sign In'
                      : "Don't have an account? Create one now",
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Trust & Security Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 8),
                Text(
                  'End-to-end encrypted • Supabase Cloud',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
