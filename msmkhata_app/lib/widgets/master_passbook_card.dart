import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/stats.dart';
import '../services/budget_service.dart';
import '../services/theme_service.dart';
import 'animated_currency_text.dart';

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
    final isBalancePositive = stats.netAccountBalance >= 0;

    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: BudgetService.privateModeNotifier,
          builder: (context, isPrivate, _) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.cardBg, accent.primary.withValues(alpha: 0.35), const Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accent.light.withValues(alpha: 0.45),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.glow.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Account Name Badge (with Primary span underneath) & Eye Privacy Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: Color(0xFFA5B4FC),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                account.name,
                                style: const TextStyle(
                                  color: Color(0xFFE0E7FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (account.isDefault) ...[
                                const SizedBox(height: 1),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Primary',
                                    style: TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      // Eye Privacy Toggle Button (No text, eye icon only)
                      Tooltip(
                        message: isPrivate ? 'Show Balances' : 'Hide Balances (Privacy)',
                        child: InkWell(
                          onTap: BudgetService.togglePrivateMode,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isPrivate
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPrivate
                                    ? const Color(0xFFF87171).withValues(alpha: 0.6)
                                    : const Color(0xFF818CF8).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 15,
                              color: isPrivate ? const Color(0xFFF87171) : const Color(0xFFC7D2FE),
                            ),
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

                  // Large Master Available Balance with Counting Animation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCurrencyText(
                        value: stats.netAccountBalance,
                        isPrivate: isPrivate,
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

                  // Middle Row: Total Money In vs Total Money Out (Animated Counting)
                  Row(
                    children: [
                      Expanded(
                        child: _buildPassbookMetric(
                          label: 'Total Money In',
                          sub: 'Income & Received',
                          value: stats.totalMoneyIn,
                          prefix: '+ ₹',
                          isPrivate: isPrivate,
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
                            value: stats.totalMoneyOut,
                            prefix: '- ₹',
                            isPrivate: isPrivate,
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

                  // Bottom Row: Market Len-Den Standing (Receivables & Payables Animated)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.handshake_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          const Text(
                            'Market Lena: ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          AnimatedCurrencyText(
                            value: stats.totalReceivable,
                            isPrivate: isPrivate,
                            maskText: '••••',
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            'Market Dena: ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          AnimatedCurrencyText(
                            value: stats.totalPayable,
                            isPrivate: isPrivate,
                            maskText: '••••',
                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
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

  Widget _buildPassbookMetric({
    required String label,
    required String sub,
    required double value,
    required String prefix,
    required bool isPrivate,
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
        AnimatedCurrencyText(
          value: value,
          prefix: prefix,
          isPrivate: isPrivate,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          sub,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
      ],
    );
  }
}
