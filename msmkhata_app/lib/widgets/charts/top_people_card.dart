import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stats.dart';

class TopPeopleCard extends StatefulWidget {
  final List<PersonBalanceSummary> topDebtors;
  final List<PersonBalanceSummary> topCreditors;
  final double totalReceivable;
  final double totalPayable;

  const TopPeopleCard({
    super.key,
    required this.topDebtors,
    required this.topCreditors,
    required this.totalReceivable,
    required this.totalPayable,
  });

  @override
  State<TopPeopleCard> createState() => _TopPeopleCardState();
}

class _TopPeopleCardState extends State<TopPeopleCard> {
  // 0 = Debtors (Receivable), 1 = Creditors (Payable)
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDebtors = _activeTab == 0;
    final list = isDebtors ? widget.topDebtors : widget.topCreditors;
    final totalPool = isDebtors ? widget.totalReceivable : widget.totalPayable;
    final themeColor = isDebtors ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 480;

              final titleWidget = Row(
                mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(
                    isDebtors ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: themeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isDebtors ? 'Top Debtors (Receivable)' : 'Top Creditors (Payable)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );

              final tabSwitchWidget = Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTab(0, 'Receivable'),
                    _buildTab(1, 'Payable'),
                  ],
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    tabSwitchWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleWidget,
                  tabSwitchWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isDebtors ? 'No outstanding debts (All settled)' : 'No pending payables',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final person = list[index];
                final net = person.netBalance.abs();
                final percentage = totalPool > 0 ? (net / totalPool) * 100 : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            person.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          currency.format(net),
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Visual percentage progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}% of total pool',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _activeTab == index;
    final color = index == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
