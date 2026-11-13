import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/grocery_item.dart';
import '../services/account_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/grocery_pdf_service.dart';
import '../services/grocery_service.dart';
import '../services/routine_pdf_service.dart';
import '../services/routine_service.dart';
import '../services/security_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/daily_routine_screen.dart';
import '../screens/export_statement_screen.dart';
import '../screens/grocery_dashboard_screen.dart';
import 'account_switcher_modal.dart';
import 'export_backup_modal.dart';
import 'msm_shimmer_text.dart';
import 'theme_studio_modal.dart';

/// Ultra-Modern Frosted Glass Side-Sliding Drawer / Sub-Menu Panel for MsmKhata
class AppSideDrawer extends StatelessWidget {
  final VoidCallback? onRefresh;

  const AppSideDrawer({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        return Drawer(
          backgroundColor: Colors.transparent,
          elevation: 16,
          width: MediaQuery.of(context).size.width > 420 ? 340 : MediaQuery.of(context).size.width * 0.85,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                  border: Border(
                    right: BorderSide(color: accent.light.withValues(alpha: 0.35), width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(8, 0),
                    ),
                    BoxShadow(
                      color: accent.glow.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // 1. Header Profile & Book Snapshot
                      _buildDrawerHeader(context, accent),

                      const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),

                      // 2. Scrollable Drawer Navigation Sections
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          children: [
                            // Section A: Business & Specialized Khatas
                            _buildSectionLabel('BUSINESS & DUKAAN KHATA', Icons.storefront_rounded, accent),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.local_grocery_store_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'Grocery & Dukaan Khata',
                              subtitle: 'Item billing, stock, and customer udhaar',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GroceryDashboardScreen()),
                                );
                              },
                            ),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.event_note_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'Daily Routine & Work Diary',
                              subtitle: 'Rozana kaam ka record, tareekh aur category',
                              badge: 'NEW',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DailyRoutineScreen()),
                                );
                              },
                            ),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.auto_stories_rounded,
                              iconColor: accent.light,
                              title: 'Multi-Account Books',
                              subtitle: 'Create or switch personal & business books',
                              onTap: () {
                                Navigator.pop(context);
                                AccountSwitcherModal.show(context, onAccountChanged: onRefresh);
                              },
                            ),

                            const SizedBox(height: 14),

                            // Section B: Custom Appearance & Theme Colors
                            _buildSectionLabel('CUSTOM THEME & BORDER ACCENTS', Icons.palette_outlined, accent),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.palette_rounded,
                              iconColor: accent.light,
                              title: 'Theme & Card Accents',
                              subtitle: '${accent.name} (Active Theme)',
                              badge: 'LIVE PREVIEW',
                              onTap: () {
                                Navigator.pop(context);
                                ThemeStudioModal.show(context);
                              },
                            ),
                            const SizedBox(height: 6),
                            _buildHideBalanceToggle(accent),

                            const SizedBox(height: 14),

                            // Section C: Security & App Privacy
                            _buildSectionLabel('SECURITY & PRIVACY', Icons.shield_outlined, accent),
                            _buildSecuritySettings(context, accent),

                            const SizedBox(height: 14),

                            // Section D: Cloud Backup & Data Sync
                            _buildSectionLabel('BACKUP & STATEMENTS', Icons.cloud_outlined, accent),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: const Color(0xFFEF4444),
                              title: 'Export PDF Statement',
                              subtitle: 'Select account, dukaan khata or routine diary',
                              badge: 'MULTI-KHATA',
                              onTap: () {
                                Navigator.pop(context);
                                _showAccountStatementPicker(context, accent);
                              },
                            ),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.cloud_sync_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'Google Drive Cloud Backup',
                              subtitle: 'Automated statement PDF & Excel archival',
                              onTap: () {
                                Navigator.pop(context);
                                ExportBackupModal.show(context);
                              },
                            ),
                            _buildDrawerItem(
                              context: context,
                              accent: accent,
                              icon: Icons.sync_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'Force Cloud Resync',
                              subtitle: 'Refresh local cache with Supabase server',
                              onTap: () async {
                                Navigator.pop(context);
                                if (onRefresh != null) onRefresh!();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Syncing latest transactions with cloud...'),
                                    backgroundColor: Color(0xFF4F46E5),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),

                            // Section E: Super Administrator Control (Conditional)
                            if (AuthService.isAdmin) ...[
                              const SizedBox(height: 14),
                              _buildSectionLabel('ADMINISTRATION', Icons.admin_panel_settings_rounded, accent),
                              _buildDrawerItem(
                                context: context,
                                accent: accent,
                                icon: Icons.security_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'Admin Control Panel',
                                subtitle: 'User management & database health monitor',
                                badge: 'SUPER ADMIN',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                                  );
                                },
                              ),
                            ],

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // 3. Footer: App Info & Logout
                      const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                      _buildDrawerFooter(context, accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Top Profile and Active Ledger Snapshot Header
  Widget _buildDrawerHeader(BuildContext context, AppAccentTheme accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.light, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.glow.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: AuthService.avatarUrl != null ? NetworkImage(AuthService.avatarUrl!) : null,
                  child: AuthService.avatarUrl == null
                      ? Icon(Icons.person, color: accent.light, size: 22)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AuthService.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AuthService.email.isNotEmpty ? AuthService.email : 'Local Encrypted Mode',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Settings / Profile Edit
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8), size: 20),
                tooltip: 'Profile & Settings',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Book Card
          ValueListenableBuilder<AccountBook>(
            valueListenable: AccountService.activeAccountNotifier,
            builder: (context, activeAccount, _) {
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  AccountSwitcherModal.show(context, onAccountChanged: onRefresh);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.light.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.book_rounded, color: accent.light, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeAccount.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activeAccount.isDefault ? 'Default Account (Primary)' : 'Isolated Khata Book',
                              style: TextStyle(
                                color: accent.light,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Text('Switch', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
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

  /// Section Label Header
  Widget _buildSectionLabel(String label, IconData icon, AppAccentTheme accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: accent.light),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent.light.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Standard Interactive Drawer Item
  Widget _buildDrawerItem({
    required BuildContext context,
    required AppAccentTheme accent,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF475569)),
            ],
          ),
        ),
      ),
    );
  }

  /// Statement Account Selection Modal (Personal books, Dukaan khatas, Work diary)
  void _showAccountStatementPicker(BuildContext context, AppAccentTheme accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: accent.light.withValues(alpha: 0.4), width: 1.5),
                  left: BorderSide(color: accent.light.withValues(alpha: 0.2), width: 1),
                  right: BorderSide(color: accent.light.withValues(alpha: 0.2), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
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
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
                                ),
                                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Export PDF Statement',
                                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Kis account ya book ki statement print karni hai?',
                                    style: TextStyle(color: accent.light, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Section 1: Personal Account Books
                      _buildStatementGroupHeader('📘 PERSONAL ACCOUNTS & BOOKS', accent),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<List<AccountBook>>(
                        valueListenable: AccountService.accountsNotifier,
                        builder: (c, books, _) {
                          return Column(
                            children: books.map((book) {
                              return _buildStatementItemTile(
                                context: ctx,
                                accent: accent,
                                icon: Icons.book_rounded,
                                iconColor: accent.light,
                                title: book.name,
                                subtitle: book.isDefault ? 'Default Primary Account (Active)' : 'Isolated Khata Book',
                                badge: 'A4 STATEMENT',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ExportStatementScreen(account: book)),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Grocery & Dukaan Khatas
                      _buildStatementGroupHeader('🏪 GROCERY & DUKAAN KHATA', accent),
                      const SizedBox(height: 6),
                      if (GroceryService.cachedStores.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.storefront_outlined, color: Color(0xFF64748B), size: 16),
                              SizedBox(width: 8),
                              Text('Abhi koi dukaan khata registered nahi hai.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: GroceryService.cachedStores.map((store) {
                            return _buildStatementItemTile(
                              context: ctx,
                              accent: accent,
                              icon: Icons.storefront_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: store.storeName,
                              subtitle: '${store.category} • Pending Balance: ₹${store.pendingBalance.toStringAsFixed(0)}',
                              badge: 'DUKAAN REPORT',
                              onTap: () {
                                Navigator.pop(ctx);
                                final entries = GroceryService.cachedEntriesByStore[store.id] ?? <GroceryEntry>[];
                                GroceryPdfService.printStoreStatement(store: store, entries: entries);
                              },
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 16),

                      // Section 3: Daily Routine & Work Diary
                      _buildStatementGroupHeader('📅 DAILY ROUTINE & WORK DIARY', accent),
                      const SizedBox(height: 6),
                      _buildStatementItemTile(
                        context: ctx,
                        accent: accent,
                        icon: Icons.event_note_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Daily Routine & Work Diary Statement',
                        subtitle: 'Rozana kaam, categories, ghante aur kharche ka complete record',
                        badge: 'WORK DIARY',
                        onTap: () {
                          Navigator.pop(ctx);
                          RoutinePdfService.printRoutineStatement(
                            entries: RoutineService.cachedEntries,
                            filterLabel: 'All Dates Logged',
                            categoryLabel: 'All Categories',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatementGroupHeader(String label, AppAccentTheme accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          color: accent.light,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildStatementItemTile({
    required BuildContext context,
    required AppAccentTheme accent,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 0.8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(color: iconColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hide Balance Privacy Mode Toggle
  Widget _buildHideBalanceToggle(AppAccentTheme accent) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.hideBalanceNotifier,
      builder: (context, isHidden, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: isHidden ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Hide Balance Privacy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Mask amounts with ₹ •••••• in public', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                  ],
                ),
              ),
              Switch(
                value: isHidden,
                activeColor: accent.light,
                activeTrackColor: accent.primary.withValues(alpha: 0.5),
                onChanged: (val) => ThemeService.toggleHideBalance(val),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Security & MPIN Setup Card
  Widget _buildSecuritySettings(BuildContext context, AppAccentTheme accent) {
    return ValueListenableBuilder<bool>(
      valueListenable: SecurityService.isPinEnabledNotifier,
      builder: (context, isPinEnabled, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.light.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            children: [
              // MPIN Setup / Change Tile
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pin_rounded, color: Color(0xFF818CF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('App MPIN Lock', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          isPinEnabled ? '4-Digit PIN is active' : 'Not configured',
                          style: TextStyle(
                            color: isPinEnabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showPinSetupDialog(context, accent),
                    child: Text(
                      isPinEnabled ? 'Change' : 'Set PIN',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Biometric Unlock Switch
              ValueListenableBuilder<bool>(
                valueListenable: SecurityService.isBiometricEnabledNotifier,
                builder: (context, isBioEnabled, _) {
                  return Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Biometric Unlock', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Fingerprint / Face ID unlock', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                          ],
                        ),
                      ),
                      Switch(
                        value: isBioEnabled,
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                        onChanged: (val) {
                          if (val && !SecurityService.hasPin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kripya pehle 4-digit MPIN set karein, fir Biometric enable karein.'),
                                backgroundColor: Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _showPinSetupDialog(context, accent);
                            return;
                          }
                          SecurityService.toggleBiometric(val);
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Simple 4-Digit MPIN Setup / Change Dialog
  void _showPinSetupDialog(BuildContext context, AppAccentTheme accent) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: accent.light, size: 22),
            const SizedBox(width: 10),
            const Text('Setup 4-Digit MPIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App ko private aur safe rakhne ke liye 4-digit ka MPIN darj karein:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'PIN',
                hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 2),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.light)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Confirm PIN',
                hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 2),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.light)),
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
            style: ElevatedButton.styleFrom(backgroundColor: accent.primary),
            onPressed: () async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN 4-digit ka hona chahiye.'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              if (pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN match nahi hua.'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              await SecurityService.setPin(pin);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('MPIN successfully set ho gaya!'), backgroundColor: Color(0xFF10B981)),
              );
            },
            child: const Text('Save PIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Drawer Footer Info & Logout
  Widget _buildDrawerFooter(BuildContext context, AppAccentTheme accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              MsmShimmerText(
                text: 'ORG : msm.movin 2022',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                'v1.0.14 • Created by Mohd Salman',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
              ),
            ],
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout_rounded, size: 14),
            label: const Text('Sign Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

