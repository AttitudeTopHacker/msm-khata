import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/grocery_dashboard_screen.dart';
import '../screens/daily_routine_screen.dart';

/// Interactive Quick Modules Hub: Displays Grocery Ledger and Work Diary cards
/// Triggered instantly by a trackpad or touchscreen pinch-in gesture, or a shortcut.
class QuickModulesModal extends StatelessWidget {
  const QuickModulesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Quick Modules Hub',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => const QuickModulesModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 540;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF334155).withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF818CF8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Modules Hub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pinch in detected • Select specialized ledger module',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                          tooltip: 'Close (Esc)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Cards Layout
                    isCompact
                        ? Column(
                            children: [
                              _buildModuleCard(
                                context: context,
                                title: 'Grocery Ledger',
                                hindiTitle: 'किराना और राशन बहीखाता',
                                subtitle: 'Manage store credits, monthly grocery bills & daily ration item list',
                                icon: Icons.local_grocery_store_rounded,
                                badge: 'Grocery & Stores',
                                gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                                accentColor: const Color(0xFF10B981),
                                buttonText: 'Open Grocery Ledger →',
                                onOpen: () {
                                  Navigator.of(context).pop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const GroceryDashboardScreen()),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildModuleCard(
                                context: context,
                                title: 'Work Diary',
                                hindiTitle: 'काम डायरी और दैनिक रूटीन',
                                subtitle: 'Log daily farming routine, tractor hours, labour entries & tasks',
                                icon: Icons.menu_book_rounded,
                                badge: 'Work & Routine',
                                gradientColors: const [Color(0xFF4F46E5), Color(0xFF818CF8)],
                                accentColor: const Color(0xFF818CF8),
                                buttonText: 'Open Work Diary →',
                                onOpen: () {
                                  Navigator.of(context).pop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const DailyRoutineScreen()),
                                  );
                                },
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildModuleCard(
                                  context: context,
                                  title: 'Grocery Ledger',
                                  hindiTitle: 'किराना और राशन बहीखाता',
                                  subtitle: 'Manage store credits, monthly grocery bills & daily ration items',
                                  icon: Icons.local_grocery_store_rounded,
                                  badge: 'Grocery & Stores',
                                  gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                                  accentColor: const Color(0xFF10B981),
                                  buttonText: 'Open Grocery Ledger →',
                                  onOpen: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GroceryDashboardScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildModuleCard(
                                  context: context,
                                  title: 'Work Diary',
                                  hindiTitle: 'काम डायरी और दैनिक रूटीन',
                                  subtitle: 'Log daily farming routine, tractor hours, labour entries & tasks',
                                  icon: Icons.menu_book_rounded,
                                  badge: 'Work & Routine',
                                  gradientColors: const [Color(0xFF4F46E5), Color(0xFF818CF8)],
                                  accentColor: const Color(0xFF818CF8),
                                  buttonText: 'Open Work Diary →',
                                  onOpen: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const DailyRoutineScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 18),

                    // Gesture Tip Bar at Bottom
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155), width: 0.8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.pinch_rounded, size: 16, color: Color(0xFF38BDF8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tip: Pinch in on touchpad or touchscreen (middle of screen) anytime to pop up this launcher!',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required String hindiTitle,
    required String subtitle,
    required IconData icon,
    required String badge,
    required List<Color> gradientColors,
    required Color accentColor,
    required String buttonText,
    required VoidCallback onOpen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top icon & badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title & Hindi Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hindiTitle,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle description
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // Launch button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
