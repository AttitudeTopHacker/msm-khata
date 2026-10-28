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
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF4F46E5).withOpacity(0.3),
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSwitched,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF818CF8)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF818CF8)),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.insights_rounded, color: Color(0xFF818CF8)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF818CF8)),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
