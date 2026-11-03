import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/policy_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  AdminDashboardStats? _stats;
  List<AdminUserItem> _users = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PolicyService.fetchPolicies();
      final statsFuture = AdminService.fetchDashboardStats();
      final usersFuture = AdminService.fetchUsersList();

      final results = await Future.wait([statsFuture, usersFuture]);
      if (mounted) {
        setState(() {
          _stats = results[0] as AdminDashboardStats;
          _users = results[1] as List<AdminUserItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Policy Toggle Handlers
  // ---------------------------------------------------------------------------
  Future<void> _handleTogglePolicy(String key, bool newValue) async {
    final success = await PolicyService.updatePolicy(key, newValue);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update system policy. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Confirmation Dialogs (Accidental Click Protection)
  // ---------------------------------------------------------------------------
  Future<void> _confirmAndToggleSuspension(AdminUserItem user) async {
    if (user.isPrimaryAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The primary administrator account cannot be suspended.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final willSuspend = !user.isSuspended;
    final actionWord = willSuspend ? 'Suspend' : 'Unsuspend';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: willSuspend ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Icon(
              willSuspend ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: willSuspend ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              '$actionWord User Account?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          willSuspend
              ? 'Are you certain you wish to suspend "${user.displayName}" (${user.email})? While suspended, this user will be blocked from performing ledger operations.'
              : 'Are you certain you wish to reinstate and unsuspend "${user.displayName}" (${user.email})? Their standard ledger access will be restored.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willSuspend ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              foregroundColor: willSuspend ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '$actionWord Account',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AdminService.toggleUserSuspension(
        userId: user.id,
        userEmail: user.email,
        suspend: willSuspend,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "${user.displayName}" has been successfully ${willSuspend ? "suspended" : "unsuspended"}.'),
            backgroundColor: willSuspend ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteUser(AdminUserItem user) async {
    if (user.isPrimaryAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The primary administrator account cannot be deleted.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete User Account?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${user.displayName}" (${user.email})?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action will permanently delete all transactions, contacts, categories, and account records associated with this user. This process cannot be reversed.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AdminService.deleteUserAccount(
        userId: user.id,
        userEmail: user.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account for "${user.displayName}" has been permanently deleted.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Access security guard
    if (!AuthService.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Access Denied', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Privileges Required',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This control panel is strictly restricted to mohdsalman4151@gmail.com.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Administrator Control Panel',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Dashboard',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
            onPressed: _loadAllAdminData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadAllAdminData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF4F46E5),
                  backgroundColor: const Color(0xFF1E293B),
                  onRefresh: _loadAllAdminData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Admin Identity Banner
                        _buildAdminIdentityBanner(),
                        const SizedBox(height: 20),

                        // Section 1: Metrics Overview Cards
                        _buildMetricsCards(),
                        const SizedBox(height: 26),

                        // Section 2: Global Policy Controllers (The 3 Core On/Off Toggles)
                        _buildPolicyControllersSection(),
                        const SizedBox(height: 28),

                        // Section 3: User Governance & Directory
                        _buildUserManagementSection(filteredUsers),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget Components
  // ---------------------------------------------------------------------------
  Widget _buildAdminIdentityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF59E0B).withOpacity(0.2),
            child: const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary Administrator Session',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'mohdsalman4151@gmail.com',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981), width: 0.8),
            ),
            child: const Text(
              'Super Admin',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final count = isWide ? 4 : 2;

        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 1.6 : 1.35,
          children: [
            _buildMetricTile(
              label: 'Total Users',
              value: stats.totalUsers.toString(),
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF38BDF8),
            ),
            _buildMetricTile(
              label: 'Active Users',
              value: stats.activeUsers.toString(),
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildMetricTile(
              label: 'Suspended Users',
              value: stats.suspendedUsers.toString(),
              icon: Icons.pause_circle_filled_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _buildMetricTile(
              label: 'Total Entries',
              value: stats.totalTransactions.toString(),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF818CF8),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyControllersSection() {
    return ValueListenableBuilder<int>(
      valueListenable: PolicyService.policyVersion,
      builder: (context, _, __) {
        final canEdit = PolicyService.canEditEntry;
        final canDelete = PolicyService.canDeleteEntry;
        final canEditDate = PolicyService.canEditDate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 20),
                SizedBox(width: 8),
                Text(
                  'Global Ledger Policy Controllers',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Enforce app-wide operation restrictions. Toggling an option OFF immediately disables corresponding buttons for all users and displays restriction notices.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Controller 1: Allow Entry Editing
            _buildPolicyToggleCard(
              title: 'Allow Entry Editing',
              description: 'When disabled, users cannot edit or update existing transactions. New ledger entries can still be recorded without restriction.',
              icon: Icons.edit_note_rounded,
              value: canEdit,
              onChanged: (val) => _handleTogglePolicy('allow_entry_update', val),
            ),
            const SizedBox(height: 12),

            // Controller 2: Allow Old Entry Deletion
            _buildPolicyToggleCard(
              title: 'Allow Old Entry Deletion',
              description: 'When disabled, historical ledger transactions cannot be permanently deleted by users.',
              icon: Icons.delete_sweep_rounded,
              value: canDelete,
              onChanged: (val) => _handleTogglePolicy('allow_entry_delete', val),
            ),
            const SizedBox(height: 12),

            // Controller 3: Allow Date Modification
            _buildPolicyToggleCard(
              title: 'Allow Date Modification',
              description: 'When disabled, users cannot alter or backdate transaction dates when viewing or modifying records.',
              icon: Icons.calendar_month_rounded,
              value: canEditDate,
              onChanged: (val) => _handleTogglePolicy('allow_date_edit', val),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPolicyToggleCard({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? const Color(0xFF334155) : const Color(0xFFEF4444).withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: value ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value ? 'Enabled' : 'Restricted',
                        style: TextStyle(
                          color: value ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
            inactiveThumbColor: const Color(0xFFEF4444),
            inactiveTrackColor: const Color(0xFFEF4444).withOpacity(0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementSection(List<AdminUserItem> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.manage_accounts_rounded, color: Color(0xFF38BDF8), size: 20),
                SizedBox(width: 8),
                Text(
                  'User Governance & Directory',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '${users.length} registered',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search user by name or email address...',
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No users match your search criteria.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user);
            },
          ),
      ],
    );
  }

  Widget _buildUserCard(AdminUserItem user) {
    final isSuspended = user.isSuspended;
    final isPrimaryAdmin = user.isPrimaryAdmin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuspended
              ? const Color(0xFFF59E0B).withOpacity(0.5)
              : isPrimaryAdmin
                  ? const Color(0xFFF59E0B).withOpacity(0.3)
                  : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isPrimaryAdmin
                    ? const Color(0xFFF59E0B).withOpacity(0.2)
                    : const Color(0xFF4F46E5).withOpacity(0.2),
                backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                child: user.avatarUrl.isEmpty
                    ? Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isPrimaryAdmin ? const Color(0xFFF59E0B) : const Color(0xFF818CF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
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
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimaryAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuspended
                      ? const Color(0xFFEF4444).withOpacity(0.15)
                      : const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuspended ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSuspended ? 'Suspended' : 'Active',
                      style: TextStyle(
                        color: isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 10),

          // User Metadata & Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF64748B), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    '${user.transactionsCount} entries',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  if (user.createdAt != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B), size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'Joined ${DateFormat('dd MMM yyyy').format(user.createdAt!)}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                    ),
                  ],
                ],
              ),

              // Action Buttons: Suspend/Unsuspend & Delete (Guarded against accidental touch)
              if (!isPrimaryAdmin)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Suspend / Unsuspend Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        side: BorderSide(
                          color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          width: 0.9,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmAndToggleSuspension(user),
                      icon: Icon(
                        isSuspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 15,
                      ),
                      label: Text(
                        isSuspended ? 'Unsuspend' : 'Suspend',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete User Button
                    IconButton(
                      tooltip: 'Permanently Delete User Account',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                      onPressed: () => _confirmAndDeleteUser(user),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

