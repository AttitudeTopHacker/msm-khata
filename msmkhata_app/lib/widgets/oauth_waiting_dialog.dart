import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/desktop_auth_service.dart';

/// Interactive modal dialog displayed on Desktop while waiting for
/// the user to complete Google or GitHub sign-in in the external browser (Chrome).
///
/// It provides:
/// 1. Real-time feedback that the desktop app is actively waiting.
/// 2. Clear instructions that they can safely close the Chrome tab once approved.
/// 3. Immediate auto-dismissal and transition to the Dashboard upon receiving the OAuth session.
/// 4. An escape hatch to cancel or paste the callback URL manually if needed.
class OAuthWaitingDialog extends StatefulWidget {
  final String provider; // 'google' or 'github'

  const OAuthWaitingDialog({
    super.key,
    required this.provider,
  });

  /// Helper static method to show the waiting dialog
  static Future<void> show(BuildContext context, {required String provider}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OAuthWaitingDialog(provider: provider),
    );
  }

  @override
  State<OAuthWaitingDialog> createState() => _OAuthWaitingDialogState();
}

class _OAuthWaitingDialogState extends State<OAuthWaitingDialog> with SingleTickerProviderStateMixin {
  StreamSubscription<AuthState>? _authSub;
  bool _isSuccess = false;
  String? _errorMessage;
  bool _showManualPaste = false;
  final TextEditingController _pasteController = TextEditingController();
  bool _isManualSubmitting = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Check if already authenticated
    if (AuthService.isAuthenticated) {
      _handleSuccess();
      return;
    }

    // Listen for OAuth session arrival from browser deep link
    _authSub = AuthService.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        _handleSuccess();
      }
    });

    // Initiate the OAuth flow in the background
    _startOAuth();
  }

  void _startOAuth() async {
    try {
      if (widget.provider == 'google') {
        await AuthService.signInWithGoogle();
      } else {
        await AuthService.signInWithGitHub();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').replaceAll('AuthException:', '').trim();
        });
      }
    }
  }

  void _handleSuccess() {
    if (!mounted || _isSuccess) return;
    setState(() => _isSuccess = true);

    // Allow user to see the success confirmation, then pop all modal routes back to root
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
    });
  }

  void _handleManualPaste() async {
    final rawUrl = _pasteController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() => _isManualSubmitting = true);
    try {
      final uri = Uri.parse(rawUrl);
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      // Success will be caught by _authSub
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Invalid callback URL: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isManualSubmitting = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pulseController.dispose();
    _pasteController.dispose();
    DesktopLoopbackAuth.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerTitle = widget.provider == 'google' ? 'Google' : 'GitHub';

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSuccess) ...[
                // Success State
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Signed In Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, ${AuthService.displayName}!\nOpening your ledger dashboard...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF10B981),
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                // Error State
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign-In Failed',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _errorMessage = null);
                          _startOAuth();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Active Waiting State
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.provider == 'google'
                          ? const Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'sans-serif',
                              ),
                            )
                          : const Icon(Icons.terminal_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  '$providerTitle Sign-In Opened in Chrome',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Please select your account and approve sign-in in your Chrome browser window.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Information Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Listening for authorization callback...',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: You can safely close the Chrome tab once approved.',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _showManualPaste = !_showManualPaste);
                      },
                      child: Text(
                        _showManualPaste ? 'Hide paste link' : 'Trouble connecting?',
                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),

                // Manual URL Paste Expandable Field
                if (_showManualPaste) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pasteController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Paste callback URL from Chrome...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isManualSubmitting ? null : _handleManualPaste,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: _isManualSubmitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Complete Sign-In Manually', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
