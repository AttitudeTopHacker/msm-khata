import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final f = ApiService.getDashboardStats();
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
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
            final savingsRate = stats.totalIncome > 0
                ? ((stats.netSavings / stats.totalIncome) * 100).clamp(-100.0, 100.0)
                : 0.0;

            return SingleChildScrollView(
              physics: AdaptiveRefreshIndicator.scrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Financial Health Matrix (KPI Cards)
                  const Text(
                    'Financial Health Overview',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Income',
                          amount: currency.format(stats.totalIncome),
                          sub: 'Earnings',
                          color: const Color(0xFF10B981),
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Expense',
                          amount: currency.format(stats.totalExpense),
                          sub: 'Expenditure',
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
                          title: 'Net Savings',
                          amount: currency.format(stats.netSavings),
                          sub: '${savingsRate.toStringAsFixed(1)}% savings rate',
                          color: stats.netSavings >= 0 ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Transactions',
                          amount: '${stats.totalTransactionsCount}',
                          sub: 'All Ledger Entries',
                          color: const Color(0xFF818CF8),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Monthly Cash Flow & Len-Den Trends Bar Chart
                  MonthlyTrendChart(trends: stats.monthlyTrends),

                  const SizedBox(height: 20),

                  // 3. Category Spending Donut / Pie Chart with %
                  CategoryPieChart(
                    categories: stats.categoryBreakdown,
                    totalExpense: stats.totalExpense,
                  ),

                  const SizedBox(height: 20),

                  // 4. Top Debtors & Top Creditors Highlight Card
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
