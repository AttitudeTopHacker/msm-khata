import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/msm_shimmer_text.dart';
import '../widgets/github_developer_card.dart';
import '../widgets/oauth_waiting_dialog.dart';
import 'auth_screen.dart';
import '../main.dart';

class LandingScreen extends StatefulWidget {
  final bool isViewingFromDashboard;

  const LandingScreen({super.key, this.isViewingFromDashboard = false});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String? _loadingProvider; // 'google', 'github', or null
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = AuthService.onAuthStateChange.listen((data) {
      // ONLY close if not viewing from dashboard and freshly signed in!
      if (!widget.isViewingFromDashboard &&
          data.event == AuthChangeEvent.signedIn &&
          data.session != null &&
          mounted) {
        // Automatically close the sign-in modal bottom sheet once authenticated
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _navigateToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  void _handleGoogleSignIn() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      if (Navigator.of(context).canPop() && !widget.isViewingFromDashboard) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
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
      if (Navigator.of(context).canPop() && !widget.isViewingFromDashboard) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
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

  String _formatErrorMessage(String raw) {
    if (raw.contains('provider is not enabled') || raw.contains('validation_failed')) {
      return 'OAuth provider is not enabled yet in your Supabase dashboard. Please enable Google / GitHub in Authentication > Providers.';
    }
    return raw.replaceAll('Exception:', '').replaceAll('AuthException:', '').trim();
  }

  void _showSignInModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign In to MsmKhata',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your ledger data is completely private and tied to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildOAuthButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavBar(context),
            if (widget.isViewingFromDashboard) _buildDashboardReturnBanner(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroSection(context),
                    _buildDataIsolationBanner(),
                    _buildFeatureCards(),
                    _buildDeveloperSection(),
                    _buildPreviewShowcase(),
                    _buildBottomCta(),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardReturnBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: const Color(0xFF4F46E5).withOpacity(0.18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF818CF8), size: 14),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Viewing Public Home Page • Tap Dashboard anytime to return.',
              style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 11.5, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Return',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Top Navigation Bar (Fixed Header)
  Widget _buildTopNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 360;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'MsmKhata',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              MsmShimmerText(
                                text: 'ORG : msm.movin 2022',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                ' • Ledger',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isViewingFromDashboard || AuthService.currentSession != null)
                Tooltip(
                  message: 'Back to Dashboard',
                  child: isVeryNarrow
                      ? IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _navigateToDashboard,
                          icon: const Icon(Icons.dashboard_rounded, size: 18),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _navigateToDashboard,
                          icon: const Icon(Icons.dashboard_rounded, size: 16),
                          label: const Text(
                            'Dashboard',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                )
              else
                Tooltip(
                  message: 'Sign In',
                  child: isVeryNarrow
                      ? IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showSignInModal(context),
                          icon: const Icon(Icons.login_rounded, size: 18),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showSignInModal(context),
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  // 2. Hero Section
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Next-Gen Badge with msm.movin 2022 Shimmer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 14),
                  SizedBox(width: 6),
                  MsmShimmerText(
                    text: 'ORG : msm.movin 2022',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '• 100% Private Cloud Ledger',
                    style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main Title
            const Text(
              'Your Personal Ledger.\nCompletely Isolated & Private.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),

            // Subtitle
            const Text(
              'Track receivables, payables, Mandi, and agricultural expenses with real-time financial analytics. Each user has their own private database — no one else can view your financial data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Error display
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Hero Action Area: If logged in, show Dashboard return card; if not, show OAuth Sign-In
            if (widget.isViewingFromDashboard || AuthService.currentSession != null)
              Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Private Ledger Active',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                AuthService.email.isNotEmpty ? AuthService.email : 'Cloud Account Synchronised',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _navigateToDashboard,
                      icon: const Icon(Icons.dashboard_rounded, size: 18),
                      label: const Text('Open Private Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Get Started in One Click',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to unlock your private dashboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    _buildOAuthButtons(),
                    const SizedBox(height: 14),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Secured by Supabase • Private per-user records',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 3. Data Isolation & Privacy Banner
  Widget _buildDataIsolationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-User Privacy Guaranteed',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Every account has an isolated ledger database. When you log in with Google or GitHub, your transactions, contacts, and balances are strictly private to you. No other user can see your records.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Feature Cards
  Widget _buildFeatureCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        children: [
          const Text(
            'Everything You Need For Your Financial Ledger',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Built specifically for personal finance, Mandi trade, and agricultural management',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFeatureCard(
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF818CF8),
                title: 'Smart Len-Den Tracking',
                description: 'Record money given (receivable) and taken (payable) with instant person-wise balance calculation and settlement.',
              ),
              _buildFeatureCard(
                icon: Icons.agriculture_rounded,
                iconColor: const Color(0xFF84CC16),
                title: 'Agricultural & Mandi Tags',
                description: 'Pre-configured categories for Mandi, Ploughing, Irrigation, Diesel, Labour, and Seeds, plus custom category creation.',
              ),
              _buildFeatureCard(
                icon: Icons.pie_chart_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Visual Spending Analytics',
                description: 'Inspect monthly trends, category donut distributions, and top debtors/creditors in real time.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  // 5. Preview Showcase Mockup
  Widget _buildPreviewShowcase() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.dashboard_rounded, color: Color(0xFF818CF8), size: 18),
                  SizedBox(width: 8),
                  Text('Dashboard Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Live Mock Preview', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMockMetric('Net Balance', '₹15,400', const Color(0xFF10B981)),
                _buildMockMetric('Receivable', '₹22,000', const Color(0xFF10B981)),
                _buildMockMetric('Payable', '₹6,600', const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 6. Bottom Call to Action
  Widget _buildBottomCta() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: (widget.isViewingFromDashboard || AuthService.currentSession != null)
          ? Column(
              children: [
                const Text(
                  'Your Private Ledger is Active',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are signed in as ${AuthService.email.isNotEmpty ? AuthService.email : "Authorized User"}. Return to your dashboard anytime.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 250,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _navigateToDashboard,
                    icon: const Icon(Icons.dashboard_rounded, size: 18),
                    label: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const Text(
                  'Ready to Manage Your Finances?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with Google or GitHub to start recording your personal transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _buildOAuthButtons(),
                ),
              ],
            ),
    );
  }

  // Reusable OAuth Buttons
  Widget _buildOAuthButtons() {
    final isGoogleLoading = _loadingProvider == 'google';
    final isGitHubLoading = _loadingProvider == 'github';
    final isAnyLoading = _loadingProvider != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: isAnyLoading ? null : _handleGoogleSignIn,
            child: isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              color: Color(0xFF4285F4),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // GitHub Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155), width: 1.2),
              ),
              elevation: 0,
            ),
            onPressed: isAnyLoading ? null : _handleGitHubSignIn,
            child: isGitHubLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.terminal_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Continue with GitHub',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Direct In-App Email & Password Option
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
          icon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF818CF8), size: 16),
          label: const Text(
            'Sign In / Register with Email (In-App)',
            style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),

        // Desktop Manual URL Paste Helper
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows)) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _showPasteCallbackUrlDialog,
            icon: const Icon(Icons.link_rounded, color: Color(0xFF94A3B8), size: 15),
            label: const Text(
              'Paste Auth Callback URL (Desktop Helper)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _showPasteCallbackUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: const Row(
          children: [
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
              'If your browser opened the login link but did not return automatically to MsmKhata, copy the URL from your browser address bar and paste it below:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'io.supabase.msmkhata://login-callback/#access_token=... OR ...?code=...',
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

  // 5. Developer Profile Section
  Widget _buildDeveloperSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          const Text(
            'Lead Architect & Engineering',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Crafted by ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              MsmShimmerText(
                text: 'ORG : msm.movin 2022',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(' • Developer Showcase', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const GithubDeveloperCard(),
        ],
      ),
    );
  }

  // 7. Footer
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              Text(
                '© 2026 MsmKhata • Engineered by ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              MsmShimmerText(
                text: 'ORG : msm.movin 2022',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                ' • Powered by Supabase Cloud',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

