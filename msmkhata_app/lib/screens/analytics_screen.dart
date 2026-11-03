import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../widgets/charts/category_pie_chart.dart';
import '../widgets/charts/monthly_trend_chart.dart';
import '../widgets/charts/top_people_card.dart';
import '../widgets/adaptive_refresh_indicator.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sync_status_badge.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<DashboardStats> _statsFuture;
  bool _isSyncing = false;
  String _selectedYear = 'All'; // 'All', '2026', '2025', etc.

  @override
  void initState() {
    super.initState();
    SyncService.dataVersion.addListener(_onDataVersionChanged);
    _loadStats();
  }

  @override
  void dispose() {
    SyncService.dataVersion.removeListener(_onDataVersionChanged);
    super.dispose();
  }

  void _onDataVersionChanged() {
    if (mounted && SyncService.cachedStats != null) {
      setState(() {
        _statsFuture = Future.value(SyncService.cachedStats!);
      });
    }
  }

  Future<DashboardStats> _getStats() async {
    final s = await SyncService.syncStats();
    if (s != null) return s;
    return await ApiService.getDashboardStats();
  }

  Future<void> _loadStats() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final f = _getStats();
    setState(() {
      _statsFuture = f;
    });
    try {
      await f;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<String> _extractAvailableYears(DashboardStats stats) {
    final Set<String> years = {};
    for (final t in stats.monthlyTrends) {
      final parts = t.month.split('-');
      if (parts.isNotEmpty && parts[0].length == 4) {
        years.add(parts[0]);
      }
    }
    for (final tx in SyncService.cachedTransactions) {
      if (tx.transactionDate != null && tx.transactionDate!.length >= 4) {
        final y = tx.transactionDate!.substring(0, 4);
        if (int.tryParse(y) != null) {
          years.add(y);
        }
      }
    }
    if (years.isEmpty) {
      years.add(DateTime.now().year.toString());
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...sorted];
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics & Insights',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
            Text(
              'Data Analyst View • Deep Financial Trends',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          SyncStatusBadge(
            isSyncing: _isSyncing,
            onSync: _loadStats,
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: AdaptiveRefreshIndicator(
        color: const Color(0xFF818CF8),
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: _loadStats,
        child: FutureBuilder<DashboardStats>(
          future: _statsFuture,
          initialData: SyncService.cachedStats,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const ShimmerAnalyticsOverview();
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to connect to backend:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                        onPressed: _loadStats,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final stats = snapshot.data!;
            final availableYears = _extractAvailableYears(stats);

            // Filter monthly trends based on selected year
            final List<MonthlyTrendItem> filteredTrends = _selectedYear == 'All'
                ? stats.monthlyTrends
                : stats.monthlyTrends.where((t) => t.month.startsWith(_selectedYear)).toList();

            // Calculate Year-Specific Totals
            double activeIncome = 0.0;
            double activeExpense = 0.0;

            if (_selectedYear == 'All') {
              activeIncome = stats.totalIncome;
              activeExpense = stats.totalExpense;
            } else {
              for (final t in filteredTrends) {
                activeIncome += t.totalIncome;
                activeExpense += t.totalExpense;
              }
            }

            final netBenefit = activeIncome - activeExpense;
            final isProfitable = netBenefit >= 0;
            final benefitRate = activeIncome > 0
                ? ((netBenefit / activeIncome) * 100).clamp(-100.0, 100.0)
                : 0.0;

            return SingleChildScrollView(
              physics: AdaptiveRefreshIndicator.scrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. YEAR-WISE SELECTOR BAR
                  _buildYearFilterBar(availableYears),
                  const SizedBox(height: 16),

                  // 1. BENEFITS & LOSS (P&L) HIGHLIGHT MATRIX CARD
                  _buildBenefitLossCard(
                    currency: currency,
                    income: activeIncome,
                    expense: activeExpense,
                    netBenefit: netBenefit,
                    isProfitable: isProfitable,
                    rate: benefitRate,
                    trends: filteredTrends,
                  ),
                  const SizedBox(height: 20),

                  // 2. Financial Health Matrix (KPI Cards)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financial Performance',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          _selectedYear == 'All' ? 'All Time Overview' : 'Year $_selectedYear Record',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Income',
                          amount: currency.format(activeIncome),
                          sub: _selectedYear == 'All' ? 'All-Time Earnings' : '$_selectedYear Earnings',
                          color: const Color(0xFF10B981),
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Expense',
                          amount: currency.format(activeExpense),
                          sub: _selectedYear == 'All' ? 'All-Time Expenses' : '$_selectedYear Expenditure',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: isProfitable ? 'Net Benefit (Profit)' : 'Net Loss (Deficit)',
                          amount: currency.format(netBenefit.abs()),
                          sub: isProfitable
                              ? '+${benefitRate.toStringAsFixed(1)}% Net Margin'
                              : '-${benefitRate.abs().toStringAsFixed(1)}% Deficit',
                          color: isProfitable ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                          icon: isProfitable ? Icons.savings_outlined : Icons.money_off_csred_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Transactions',
                          amount: '${_selectedYear == 'All' ? stats.totalTransactionsCount : filteredTrends.length > 0 ? stats.totalTransactionsCount : 0}',
                          sub: 'Recorded Ledger Rows',
                          color: const Color(0xFF818CF8),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Monthly Cash Flow & Len-Den Trends Bar Chart
                  MonthlyTrendChart(trends: filteredTrends),

                  const SizedBox(height: 20),

                  // 4. Category Spending Donut / Pie Chart with %
                  CategoryPieChart(
                    categories: stats.categoryBreakdown,
                    totalExpense: stats.totalExpense,
                  ),

                  const SizedBox(height: 20),

                  // 5. Top Debtors & Top Creditors Highlight Card
                  TopPeopleCard(
                    topDebtors: stats.topDebtors,
                    topCreditors: stats.topCreditors,
                    totalReceivable: stats.totalReceivable,
                    totalPayable: stats.totalPayable,
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Year Filter Bar
  // ---------------------------------------------------------------------------
  Widget _buildYearFilterBar(List<String> years) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, color: Color(0xFF818CF8), size: 18),
          const SizedBox(width: 10),
          const Text(
            'Select Year:',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: years.map((y) {
                  final isSelected = _selectedYear == y;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(y == 'All' ? 'All Years' : y),
                      selected: isSelected,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                        width: isSelected ? 1.4 : 0.8,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedYear = y;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Benefits vs Loss (Profit & Loss / P&L) Highlight Card
  // ---------------------------------------------------------------------------
  Widget _buildBenefitLossCard({
    required NumberFormat currency,
    required double income,
    required double expense,
    required double netBenefit,
    required bool isProfitable,
    required double rate,
    required List<MonthlyTrendItem> trends,
  }) {
    final statusColor = isProfitable ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfitable
              ? [const Color(0xFF064E3B).withOpacity(0.4), const Color(0xFF1E293B)]
              : [const Color(0xFF7F1D1D).withOpacity(0.4), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isProfitable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Benefits vs Loss Analysis',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _selectedYear == 'All' ? 'All-Time Net Profit & Loss (P&L)' : 'Year $_selectedYear P&L Statement',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfitable ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: statusColor,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isProfitable ? 'Net Profit' : 'Net Loss',
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Big Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${isProfitable ? "+" : "-"}${currency.format(netBenefit.abs())}',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isProfitable
                    ? '(${rate.toStringAsFixed(1)}% Profit Margin)'
                    : '(${rate.abs().toStringAsFixed(1)}% Deficit)',
                style: TextStyle(color: statusColor.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Ratio Bar: Income vs Expense
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: income > 0 ? (income * 100).toInt() : 1,
                  child: Container(
                    height: 8,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: expense > 0 ? (expense * 100).toInt() : 1,
                  child: Container(
                    height: 8,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Income: ${currency.format(income)}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Expense: ${currency.format(expense)}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
