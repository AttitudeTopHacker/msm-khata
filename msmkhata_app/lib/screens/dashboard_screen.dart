import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/account_service.dart';
import '../widgets/net_position_card.dart';
import '../widgets/master_passbook_card.dart';
import '../widgets/account_switcher_modal.dart';
import '../widgets/adaptive_refresh_indicator.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sync_status_badge.dart';
import 'add_transaction_screen.dart';
import 'auth_screen.dart';
import 'export_statement_screen.dart';
import 'history_screen.dart';
import '../widgets/export_backup_modal.dart';
import '../widgets/msm_shimmer_text.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/budget_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _statsFuture;
  late Future<List<TransactionItem>> _transactionsFuture;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    AccountService.activeAccountNotifier.addListener(_onAccountChanged);
    _refreshData();
  }

  @override
  void dispose() {
    AccountService.activeAccountNotifier.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onAccountChanged() {
    if (mounted) {
      _refreshData();
    }
  }

  Future<DashboardStats> _getStats() async {
    final activeId = AccountService.activeAccountNotifier.value.id;
    final s = await SyncService.syncStats();
    if (s != null) return s;
    return await ApiService.getDashboardStats(accountId: activeId);
  }

  Future<void> _refreshData() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    // Refresh connectivity state on data refresh
    ConnectivityService.checkNow();
    final activeId = AccountService.activeAccountNotifier.value.id;
    final stats = _getStats();
    final txs = SyncService.syncTransactions(limit: 35, offset: 0);
    setState(() {
      _statsFuture = stats;
      _transactionsFuture = txs;
    });
    try {
      await Future.wait([stats, txs]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _openAddTransaction(String initialType, {double? availableBalance}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionScreen(
        initialType: initialType,
        initialAvailableBalance: availableBalance,
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final txDate = DateTime(dt.year, dt.month, dt.day);
      if (txDate == today) {
        return 'Today';
      } else if (txDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        return DateFormat('dd MMM').format(dt);
      }
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MsmKhata',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
            Row(
              children: const [
                MsmShimmerText(
                  text: 'ORG : msm.movin 2022',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  ' • Cloud Ledger',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Export & Cloud Backup Button
          IconButton(
            tooltip: 'Export Statement & Cloud Backup',
            icon: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
            onPressed: () => ExportBackupModal.show(context),
          ),
          SyncStatusBadge(
            isSyncing: _isSyncing,
            onSync: _refreshData,
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: AuthService.isAuthenticated ? 'Profile & Account Settings' : 'Sign In',
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.only(right: 14, left: 4),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AuthService.isAuthenticated ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 14,
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
            ),
          ),
        ],
      ),
      body: AdaptiveRefreshIndicator(
        color: const Color(0xFF818CF8),
        backgroundColor: const Color(0xFF1E293B),
        strokeWidth: 2.5,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AdaptiveRefreshIndicator.scrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // 0. Active Account / Book Selector Bar
                  ValueListenableBuilder<AccountBook>(
                    valueListenable: AccountService.activeAccountNotifier,
                    builder: (context, activeAccount, _) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF818CF8), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'ACTIVE BOOK',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                      if (activeAccount.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('DEFAULT', style: TextStyle(color: Color(0xFF10B981), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    activeAccount.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => AccountSwitcherModal.show(context, onAccountChanged: _refreshData),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Switch Book', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 1. Hero Card: MasterPassbookCard & NetPositionCard
                  FutureBuilder<DashboardStats>(
                    future: _statsFuture,
                    initialData: SyncService.cachedStats,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const ShimmerNetPositionCard();
                      }
                      if (snapshot.hasError) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Future.delayed(const Duration(seconds: 4), () {
                            if (mounted) _refreshData();
                          });
                        });

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Connecting to Cloud Ledger...',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Render server waking up from sleep. Auto-syncing...',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _refreshData,
                                child: const Text('Retry Now', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }
                      final stats = snapshot.data!;
                      return Column(
                        children: [
                          MasterPassbookCard(
                            stats: stats,
                            account: AccountService.activeAccountNotifier.value,
                          ),
                          const SizedBox(height: 12),
                          NetPositionCard(stats: stats),
                          const SizedBox(height: 16),
                          // 2. Highlights Banner (Analytics Graph View)
                          _buildAnalyticsHighlightCard(stats),

                          const SizedBox(height: 14),

                          // 3. Quick Action Buttons
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Quick Actions',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildActionButton(
                                label: 'Lent',
                                sub: 'Money Given',
                                color: const Color(0xFF10B981),
                                icon: Icons.call_made_rounded,
                                onTap: () => _openAddTransaction('GIVEN', availableBalance: stats.netAccountBalance),
                              ),
                              const SizedBox(width: 10),
                              _buildActionButton(
                                label: 'Borrowed',
                                sub: 'Money Taken',
                                color: const Color(0xFFEF4444),
                                icon: Icons.call_received_rounded,
                                onTap: () => _openAddTransaction('TAKEN', availableBalance: stats.netAccountBalance),
                              ),
                              const SizedBox(width: 10),
                              _buildActionButton(
                                label: 'Contacts',
                                sub: 'Parties Ledger',
                                color: const Color(0xFF818CF8),
                                icon: Icons.people_outline_rounded,
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 4. Recent Transactions Header with View All
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _isSyncing ? null : _refreshData,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.sync_rounded,
                                size: 16,
                                color: _isSyncing ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(3); // Jump to History & Filter tab
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                          }
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF818CF8)),
                        label: const Text('View All & Filter', style: TextStyle(color: Color(0xFF818CF8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 5. Recent Transactions List (Filtered by active book)
                  ValueListenableBuilder<bool>(
                    valueListenable: BudgetService.privateModeNotifier,
                    builder: (context, isPrivate, _) {
                      return FutureBuilder<List<TransactionItem>>(
                        future: _transactionsFuture,
                        initialData: SyncService.cachedTransactions.isNotEmpty ? SyncService.cachedTransactions : null,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const ShimmerTransactionList(count: 4);
                          }
                          final activeAccount = AccountService.activeAccountNotifier.value;
                          final allItems = snapshot.data ?? [];
                          final items = allItems.where((t) {
                            final itemAccountId = t.accountId ?? 'main';
                            return itemAccountId == activeAccount.id;
                          }).toList();

                          if (items.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 40,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'No transactions recorded yet in this book',
                                    style: TextStyle(color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length > 5 ? 5 : items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isGiven = item.type == 'GIVEN';
                              final isTaken = item.type == 'TAKEN';
                              final isIncome = item.type == 'INCOME';

                              final color = isGiven
                                  ? const Color(0xFF10B981)
                                  : isTaken
                                      ? const Color(0xFFEF4444)
                                      : isIncome
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFFF59E0B);

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final changed = await TransactionDetailSheet.show(
                                      context,
                                      item: item,
                                      onTransactionChanged: _refreshData,
                                    );
                                    if (changed == true) {
                                      _refreshData();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF334155), width: 0.6),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isGiven
                                                ? Icons.arrow_outward_rounded
                                                : isTaken
                                                    ? Icons.arrow_downward_rounded
                                                    : isIncome
                                                        ? Icons.account_balance_wallet_rounded
                                                        : Icons.receipt_rounded,
                                            color: color,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.personName ?? item.categoryName ?? item.type,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  if (item.transactionDate != null) ...[
                                                    Text(
                                                      _formatDate(item.transactionDate),
                                                      style: const TextStyle(
                                                        color: Color(0xFF38BDF8),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const Text(
                                                      ' • ',
                                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                                    ),
                                                  ],
                                                  Flexible(
                                                    child: Text(
                                                      item.notes?.isNotEmpty == true ? item.notes! : item.paymentMode,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              isPrivate ? '••••••' : currency.format(item.amount),
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (item.isSettled)
                                              const Text(
                                                'Settled',
                                                style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                              )
                                            else if (item.dueDate != null)
                                              Text(
                                                'Due ${item.dueDate!.substring(0, 10)}',
                                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF475569),
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 14),
                            SizedBox(width: 6),
                            MsmShimmerText(
                              text: 'ORG : msm.movin 2022',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 14),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Multi-User Isolated Cloud Accounting System',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 72),
                ],
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Add Len-Den Entry',
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        onPressed: () => _openAddTransaction('GIVEN'),
      ),
    );
  }

  Widget _buildAnalyticsHighlightCard(DashboardStats stats) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return InkWell(
      onTap: () => widget.onNavigateToTab?.call(2), // Jump to Analytics tab
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.insights_rounded, color: Color(0xFF818CF8), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visual Analytics & Graph View',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Savings: ${currency.format(stats.netSavings)} • ${stats.categoryBreakdown.length} Categories',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF818CF8), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String sub,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                sub,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
