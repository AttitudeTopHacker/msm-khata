import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/api_config.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/persons_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'services/auth_service.dart';
import 'services/account_service.dart';
import 'services/budget_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'widgets/offline_banner.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: ApiConfig.supabaseUrl,
      anonKey: ApiConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init notice: $e');
  }

  // Restore local offline cache for 0ms instant display
  await SyncService.initialize();
  await BudgetService.initialize();
  await AccountService.initialize();

  // Handle initial command-line deep link argument on Desktop (Linux / Windows)
  if (args.isNotEmpty) {
    for (final arg in args) {
      final cleanArg = arg.trim();
      if (cleanArg.contains('login-callback') ||
          cleanArg.startsWith('io.supabase.msmkhata://') ||
          cleanArg.startsWith('com.msmmovin.msmkhata://')) {
        try {
          debugPrint('Processing initial command-line auth link: $cleanArg');
          await Supabase.instance.client.auth.getSessionFromUrl(Uri.parse(cleanArg));
        } catch (e) {
          debugPrint('Initial argument auth callback error: $e');
        }
      }
    }
  }

  // Initialize network monitor and offline listener
  ConnectivityService().initialize(
    onStatusChanged: (isOnline) {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            backgroundColor:
                isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Internet jud gaya! MsmKhata online hai.'
                        : 'Internet connection band hai! Kripya apna internet connection on karein.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    },
  );

  runApp(const MsmKhataApp());
}

class MsmKhataApp extends StatelessWidget {
  const MsmKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MsmKhata',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F46E5),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Column(
          children: [
            const OfflineNoticeBar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? AuthService.currentSession;
        if (session != null) {
          return const MainNavigationScreen();
        }

        // When returning from Google/GitHub OAuth, show a clean loading splash
        if (kIsWeb) {
          final fragment = Uri.base.fragment;
          final queryParams = Uri.base.queryParameters;
          final isProcessingOAuth = fragment.contains('access_token') ||
              fragment.contains('refresh_token') ||
              queryParams.containsKey('code');
          if (isProcessingOAuth) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF818CF8)),
                    SizedBox(height: 18),
                    Text(
                      'Signing in... Preparing your private ledger',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return const LandingScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Synchronize full ledger on initial entry
    SyncService.syncAll();
  }

  void _onTabSwitched(int index) {
    setState(() => _currentIndex = index);
    // Real-time synchronization when switching pages
    if (index == 0) {
      SyncService.syncStats();
    } else if (index == 1) {
      SyncService.syncPersons();
    } else if (index == 2) {
      SyncService.syncStats();
    } else if (index == 3) {
      SyncService.syncTransactions(limit: 25, offset: 0);
    }
  }

  void _navigateToTab(int index) {
    _onTabSwitched(index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const PersonsScreen(),
      const AnalyticsScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildCustomBottomBar(),
    );
  }

  Widget _buildCustomBottomBar() {
    final navItems = const [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Contacts',
      ),
      _NavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded,
        label: 'Analytics',
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'History',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF334155).withValues(alpha: 0.65),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _currentIndex == index;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onTabSwitched(index),
                    splashColor: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sleek top active glow indicator bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 22 : 0,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF818CF8).withValues(alpha: 0.7),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        ),

                        // Active animated icon with subtle micro-pill glow
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Label text with crisp typography
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
