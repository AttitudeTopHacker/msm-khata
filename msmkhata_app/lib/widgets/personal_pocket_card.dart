import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';
import '../services/budget_service.dart';

/// Premium Personal Pocket & Monthly Budget Tracking Card for MsmKhata.
class PersonalPocketCard extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback? onBudgetUpdated;

  const PersonalPocketCard({
    super.key,
    required this.stats,
    this.onBudgetUpdated,
  });

  void _showSetBudgetDialog(BuildContext context, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '25000',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.savings_rounded, color: Color(0xFF34D399), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Monthly Expense Budget',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Personal Pocket Limit • Private & Local',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Color(0xFF34D399), fontSize: 24, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    hintText: 'Enter monthly budget amount',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Quick amount chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [10000, 20000, 30000, 50000, 100000].map((amt) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF334155)),
                      label: Text(
                        '₹${amt ~/ 1000}k',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        controller.text = amt.toString();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final val = double.tryParse(controller.text.trim());
                      if (val != null && val > 0) {
                        await BudgetService.setMonthlyBudget(val);
                        if (ctx.mounted) Navigator.pop(ctx);
                        onBudgetUpdated?.call();
                      }
                    },
                    child: const Text('Save Monthly Budget Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ValueListenableBuilder<bool>(
      valueListenable: BudgetService.privateModeNotifier,
      builder: (context, isPrivate, _) {
        return ValueListenableBuilder<double>(
          valueListenable: BudgetService.monthlyBudgetNotifier,
          builder: (context, monthlyBudget, _) {
            final spentAmount = stats.totalExpense;
            final remainingBudget = monthlyBudget - spentAmount;
            final isOverBudget = remainingBudget < 0;

            final budgetUsedRatio = monthlyBudget > 0
                ? (spentAmount / monthlyBudget).clamp(0.0, 1.0)
                : 0.0;
            final budgetUsedPct = monthlyBudget > 0
                ? ((spentAmount / monthlyBudget) * 100).clamp(0.0, 999.0)
                : 0.0;

            // Health color indicator
            final Color healthColor;
            if (isOverBudget) {
              healthColor = const Color(0xFFF87171); // Red: Over Budget
            } else if (budgetUsedRatio >= 0.80) {
              healthColor = const Color(0xFFFBBF24); // Amber: 80%+ used
            } else {
              healthColor = const Color(0xFF34D399); // Emerald: Safe
            }

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF042F2E), Color(0xFF065F46), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF047857).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title, Private mode toggle, Edit budget button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.wallet_rounded, color: Color(0xFF6EE7B7), size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Personal Pocket & Budget',
                            style: TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Privacy Eye Masking Button
                          InkWell(
                            onTap: BudgetService.togglePrivateMode,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPrivate
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPrivate ? const Color(0xFFF87171) : const Color(0xFF6EE7B7).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 13,
                                    color: isPrivate ? const Color(0xFFF87171) : const Color(0xFFA7F3D0),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPrivate ? 'Masked' : 'Private',
                                    style: TextStyle(
                                      color: isPrivate ? const Color(0xFFF87171) : const Color(0xFFA7F3D0),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Edit Budget Target Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Set Monthly Expense Budget',
                            icon: const Icon(Icons.tune_rounded, color: Color(0xFFA7F3D0), size: 18),
                            onPressed: () => _showSetBudgetDialog(context, monthlyBudget),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Remaining Budget Headline
                  Text(
                    isOverBudget ? 'Budget Exceeded' : 'Remaining Budget',
                    style: TextStyle(
                      color: isOverBudget ? const Color(0xFFFCA5A5) : const Color(0xFFD1FAE5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isPrivate ? '••••••' : currency.format(remainingBudget.abs()),
                        style: TextStyle(
                          color: isOverBudget ? const Color(0xFFFCA5A5) : Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPrivate ? '' : 'left of ${currency.format(monthlyBudget)}',
                        style: const TextStyle(
                          color: Color(0xFFA7F3D0),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Animated Linear Budget Health Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 7,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        FractionallySizedBox(
                          widthFactor: budgetUsedRatio,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: healthColor,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: healthColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOverBudget
                            ? '${(budgetUsedPct - 100).toStringAsFixed(0)}% Over Limit!'
                            : '${budgetUsedPct.toStringAsFixed(0)}% Spent',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: healthColor,
                        ),
                      ),
                      Text(
                        'Total Spent: ${isPrivate ? '••••••' : currency.format(spentAmount)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF134E4A), height: 1),
                  const SizedBox(height: 14),

                  // Bottom 3-Column Metrics: Income, Expense, Net Savings
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(
                          label: 'Income',
                          amount: isPrivate ? '••••••' : currency.format(stats.totalIncome),
                          sub: 'Earnings',
                          color: const Color(0xFF6EE7B7),
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      Container(width: 1, height: 40, color: const Color(0xFF134E4A)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _buildMetric(
                            label: 'Expense',
                            amount: isPrivate ? '••••••' : currency.format(stats.totalExpense),
                            sub: 'Expenditure',
                            color: const Color(0xFFFBBF24),
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 40, color: const Color(0xFF134E4A)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: _buildMetric(
                            label: 'Net Savings',
                            amount: isPrivate ? '••••••' : currency.format(stats.netSavings),
                            sub: stats.netSavings >= 0 ? 'Surplus' : 'Deficit',
                            color: stats.netSavings >= 0 ? const Color(0xFF38BDF8) : const Color(0xFFF87171),
                            icon: Icons.savings_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetric({
    required String label,
    required String amount,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          amount,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sub,
          style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10),
        ),
      ],
    );
  }
}
