import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/stats.dart';
import '../services/budget_service.dart';

/// Master Passbook & Real Account Balance Card for MsmKhata.
///
/// Displays:
/// - Net In-Hand / Bank Available Balance = (Money In) - (Money Out)
/// - Total Money In (Income + Taken/Received)
/// - Total Money Out (Expenses + Given/Sent)
/// - Market Len-Den Position (Receivable vs Payable)
class MasterPassbookCard extends StatelessWidget {
  final DashboardStats stats;
  final AccountBook account;

  const MasterPassbookCard({
    super.key,
    required this.stats,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isBalancePositive = stats.netAccountBalance >= 0;

    return ValueListenableBuilder<bool>(
      valueListenable: BudgetService.privateModeNotifier,
      builder: (context, isPrivate, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Account Name Badge & Privacy Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Color(0xFFA5B4FC),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        account.name,
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (account.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.6),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  // Privacy Masking Button
                  InkWell(
                    onTap: BudgetService.togglePrivateMode,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPrivate
                            ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPrivate ? const Color(0xFFF87171) : const Color(0xFF818CF8).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 13,
                            color: isPrivate ? const Color(0xFFF87171) : const Color(0xFFC7D2FE),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPrivate ? 'Masked' : 'Private',
                            style: TextStyle(
                              color: isPrivate ? const Color(0xFFF87171) : const Color(0xFFC7D2FE),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Available Balance Title
              const Text(
                'Available Account Passbook Balance',
                style: TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),

              // Large Master Available Balance
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    isPrivate
                        ? '••••••'
                        : '${isBalancePositive ? '' : '-'}${currency.format(stats.netAccountBalance.abs())}',
                    style: TextStyle(
                      color: isBalancePositive ? Colors.white : const Color(0xFFFCA5A5),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBalancePositive ? 'Liquid Funds' : 'Overdrawn',
                    style: TextStyle(
                      color: isBalancePositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF3730A3), height: 1),
              const SizedBox(height: 14),

              // Middle Row: Total Money In vs Total Money Out
              Row(
                children: [
                  Expanded(
                    child: _buildPassbookMetric(
                      label: 'Total Money In',
                      sub: 'Income & Received',
                      amount: isPrivate ? '••••••' : '+ ${currency.format(stats.totalMoneyIn)}',
                      color: const Color(0xFF34D399),
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  Container(width: 1, height: 44, color: const Color(0xFF3730A3)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: _buildPassbookMetric(
                        label: 'Total Money Out',
                        sub: 'Expenses & Paid',
                        amount: isPrivate ? '••••••' : '- ${currency.format(stats.totalMoneyOut)}',
                        color: const Color(0xFFF87171),
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: Color(0xFF3730A3), height: 1),
              const SizedBox(height: 12),

              // Bottom Row: Market Len-Den Standing (Receivables & Payables)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'Market Lena: ${isPrivate ? '••••' : currency.format(stats.totalReceivable)}',
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    'Market Dena: ${isPrivate ? '••••' : currency.format(stats.totalPayable)}',
                    style: const TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassbookMetric({
    required String label,
    required String sub,
    required String amount,
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
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sub,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
      ],
    );
  }
}
