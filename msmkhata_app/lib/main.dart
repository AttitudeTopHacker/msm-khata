import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/api_config.dart';
import 'screens/landing_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/persons_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: ApiConfig.supabaseUrl,
      anonKey: ApiConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init notice: $e');
  }
  runApp(const MsmKhataApp());
}

class MsmKhataApp extends StatelessWidget {
  const MsmKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MsmKhata',
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

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
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
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
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
