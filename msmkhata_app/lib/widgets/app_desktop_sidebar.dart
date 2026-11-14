import 'package:flutter/material.dart';
import '../models/account.dart';
import '../screens/auth_screen.dart';
import '../screens/daily_routine_screen.dart';
import '../screens/grocery_dashboard_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';
import 'account_switcher_modal.dart';
import 'app_side_drawer.dart';
import 'export_backup_modal.dart';
import 'shimmer_loading.dart';
import 'theme_studio_modal.dart';

/// Ultra-Modern Persistent Desktop Sidebar for MsmKhata.
///
/// Features:
/// 1. Designed specifically for Desktop (Linux, Windows, macOS, Wide Screens).
/// 2. Permanent docking on the left: eliminates intrusive mobile slide drawers and screen-dimming overlays.
/// 3. Collapsible / Expandable: Toggle between full 250px rich sidebar and sleek 68px icon-rail with smooth animation.
/// 4. 1-Click Fast Navigation to Grocery Khata, Routine Diary, Books, Theme Studio, MPIN, and Statement Backups.
class AppDesktopSidebar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onRefresh;

  const AppDesktopSidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        final double width = isCollapsed ? 68.0 : 252.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            border: Border(
              right: BorderSide(
                color: accent.light.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Sidebar Header (Brand / Book / Collapse Button)
                _buildSidebarHeader(context, accent),

                const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),

                // 2. Navigation Items List
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCollapsed ? 8 : 12,
                      vertical: 10,
                    ),
                    children: [
                      if (!isCollapsed)
                        _buildSectionLabel('BUSINESS & KHATA', accent),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.local_grocery_store_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Grocery Khata',
                        subtitle: 'Dukaan Udhaar & Jama',
                        tooltip: 'Grocery & Dukaan Khata',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GroceryDashboardScreen()),
                          );
                        },
                      ),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.event_note_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Work Diary',
                        subtitle: 'Rozana Kaam & Kharch',
                        tooltip: 'Daily Routine & Work Diary',
                        badge: 'NEW',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DailyRoutineScreen()),
                          );
                        },
                      ),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.auto_stories_rounded,
                        iconColor: accent.light,
                        title: 'Switch Books',
                        subtitle: 'Personal & Business books',
                        tooltip: 'Multi-Account Books',
                        onTap: () {
                          AccountSwitcherModal.show(context, onAccountChanged: onRefresh);
                        },
                      ),

                      const SizedBox(height: 10),
                      if (!isCollapsed)
                        _buildSectionLabel('APPEARANCE & SECURITY', accent),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.palette_rounded,
                        iconColor: accent.light,
                        title: 'Theme & Colors',
                        subtitle: accent.name,
                        tooltip: 'Theme & Accent Studio',
                        onTap: () {
                          ThemeStudioModal.show(context);
                        },
                      ),

                      _buildHideBalanceTile(accent),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.pin_rounded,
                        iconColor: const Color(0xFF818CF8),
                        title: 'App MPIN Lock',
                        subtitle: SecurityService.hasPin ? 'PIN is active' : 'Set 4-digit PIN',
                        tooltip: 'Security & MPIN Lock',
                        onTap: () {
                          AppSideDrawer.showPinSetupDialog(context, accent);
                        },
                      ),

                      const SizedBox(height: 10),
                      if (!isCollapsed)
                        _buildSectionLabel('STATEMENTS & SYNC', accent),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.picture_as_pdf_rounded,
                        iconColor: const Color(0xFFEF4444),
                        title: 'Export PDF',
                        subtitle: 'Print & share statement',
                        tooltip: 'Export Statement PDF',
                        badge: 'PDF',
                        onTap: () {
                          final nav = Navigator.of(context, rootNavigator: true);
                          AppSideDrawer.showAccountStatementPicker(
                            context: nav.context,
                            navigator: nav,
                            accent: accent,
                          );
                        },
                      ),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.cloud_sync_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Google Drive',
                        subtitle: 'Auto cloud statement backup',
                        tooltip: 'Google Drive Cloud Backup',
                        onTap: () {
                          ExportBackupModal.show(context);
                        },
                      ),

                      _buildSidebarItem(
                        context: context,
                        accent: accent,
                        icon: Icons.sync_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Cloud Resync',
                        subtitle: 'Sync with Supabase',
                        tooltip: 'Sync Ledger Now',
                        onTap: () {
                          if (onRefresh != null) onRefresh!();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Syncing latest transactions with Supabase...'),
                              backgroundColor: Color(0xFF4F46E5),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),

                      if (AuthService.isAdmin) ...[
                        const SizedBox(height: 10),
                        if (!isCollapsed)
                          _buildSectionLabel('ADMIN', accent),
                        _buildSidebarItem(
                          context: context,
                          accent: accent,
                          icon: Icons.admin_panel_settings_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Admin Panel',
                          subtitle: 'Super Admin Console',
                          tooltip: 'Super Admin Panel',
                          badge: 'ADMIN',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. Sidebar Footer (Profile / Collapse Toggle / Logout)
                const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                _buildSidebarFooter(context, accent),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top Sidebar Brand & Book Header
  Widget _buildSidebarHeader(BuildContext context, AppAccentTheme accent) {
    if (isCollapsed) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        child: Tooltip(
          message: 'Expand Sidebar',
          child: InkWell(
            onTap: onToggleCollapse,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.light.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.keyboard_double_arrow_right_rounded, color: accent.light, size: 20),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.primary.withValues(alpha: 0.2),
                      border: Border.all(color: accent.light, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        'MK',
                        style: TextStyle(
                          color: accent.light,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'MsmKhata',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      MsmShimmerText(
                        text: 'ORG : msm.movin',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              Tooltip(
                message: 'Collapse Sidebar',
                child: IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_left_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: onToggleCollapse,
                  splashRadius: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Active Book Pill
          ValueListenableBuilder<AccountBook>(
            valueListenable: AccountService.activeAccountNotifier,
            builder: (context, activeAccount, _) {
              return InkWell(
                onTap: () {
                  AccountSwitcherModal.show(context, onAccountChanged: onRefresh);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.light.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: accent.light, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeAccount.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.unfold_more_rounded, color: Color(0xFF94A3B8), size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Section Label (Uppercase Micro Heading)
  Widget _buildSectionLabel(String label, AppAccentTheme accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 8, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          color: accent.light.withValues(alpha: 0.85),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// Standard Desktop Sidebar Item (Adapts between Expanded & Collapsed)
  Widget _buildSidebarItem({
    required BuildContext context,
    required AppAccentTheme accent,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String tooltip,
    required VoidCallback onTap,
    String? badge,
  }) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 300),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: accent.primary.withValues(alpha: 0.15),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  border: Border.all(color: const Color(0xFF334155), width: 0.8),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: accent.primary.withValues(alpha: 0.12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 0.6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hide Balance Switch Tile
  Widget _buildHideBalanceTile(AppAccentTheme accent) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.hideBalanceNotifier,
      builder: (context, hideBalance, _) {
        if (isCollapsed) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Tooltip(
              message: hideBalance ? 'Show Balance Numbers' : 'Hide Balance Numbers',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ThemeService.toggleHideBalance(!hideBalance),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: hideBalance
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF1E293B).withValues(alpha: 0.5),
                      border: Border.all(
                        color: hideBalance ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: hideBalance ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1E293B).withValues(alpha: 0.4),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (hideBalance ? const Color(0xFFF59E0B) : const Color(0xFF64748B)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: hideBalance ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hide Balances', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(hideBalance ? 'Active (Hidden)' : 'Public mode', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: hideBalance,
                  activeColor: accent.light,
                  onChanged: (val) => ThemeService.toggleHideBalance(val),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Footer: User Profile & Auth
  Widget _buildSidebarFooter(BuildContext context, AppAccentTheme accent) {
    if (isCollapsed) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Tooltip(
          message: AuthService.isAuthenticated ? 'Account / Logout' : 'Sign In',
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: AuthService.avatarUrl != null ? NetworkImage(AuthService.avatarUrl!) : null,
              child: AuthService.avatarUrl == null
                  ? Icon(
                      AuthService.isAuthenticated ? Icons.person : Icons.account_circle_outlined,
                      size: 18,
                      color: AuthService.isAuthenticated ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: AuthService.avatarUrl != null ? NetworkImage(AuthService.avatarUrl!) : null,
            child: AuthService.avatarUrl == null
                ? Icon(
                    AuthService.isAuthenticated ? Icons.person : Icons.account_circle_outlined,
                    size: 18,
                    color: AuthService.isAuthenticated ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AuthService.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AuthService.isAuthenticated ? 'Online Cloud' : 'Encrypted Local',
                  style: TextStyle(
                    color: AuthService.isAuthenticated ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: AuthService.isAuthenticated ? 'Sign Out / Settings' : 'Sign In',
            child: IconButton(
              icon: Icon(
                AuthService.isAuthenticated ? Icons.logout_rounded : Icons.login_rounded,
                color: AuthService.isAuthenticated ? const Color(0xFFEF4444) : accent.light,
                size: 18,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

