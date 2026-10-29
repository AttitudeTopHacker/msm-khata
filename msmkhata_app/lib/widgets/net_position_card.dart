import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';
import '../services/budget_service.dart';

class NetPositionCard extends StatelessWidget {
  final DashboardStats stats;

  const NetPositionCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isNetPositive = stats.netLenDenPosition >= 0;

    // Formula requested by user: (Liquid Funds + Receivable) - Payable
    // This represents actual real net worth / final pocket balance after settling all market debts & loans.
    final liquidFunds = stats.netAccountBalance;
    final receivable = stats.totalReceivable;
    final payable = stats.totalPayable;
    final finalNetBalance = (liquidFunds + receivable) - payable;
    final isFinalPositive = finalNetBalance >= 0;

    return ValueListenableBuilder<bool>(
      valueListenable: BudgetService.privateModeNotifier,
      builder: (context, isPrivate, _) {
        String mask(String val) => isPrivate ? '••••••' : val;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
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
                color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title & Subtitle + Net Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Net Ledger Position',
                              style: TextStyle(
                                color: Color(0xFFC7D2FE),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Lene & Dene Ke Baad',
                                style: TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lene aur dene ke baad total rupaye aapke ye hain:',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFinalPositive
                          ? const Color(0xFF059669).withValues(alpha: 0.25)
                          : const Color(0xFFDC2626).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFinalPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isFinalPositive ? 'Asli Bachat' : 'Net Karza',
                      style: TextStyle(
                        color: isFinalPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main Balance Display (Real Net Worth after settlement)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    mask(currency.format(finalNetBalance)),
                    style: TextStyle(
                      color: isFinalPositive ? Colors.white : const Color(0xFFFCA5A5),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFinalPositive ? 'Net Real Worth' : 'Shortfall',
                    style: TextStyle(
                      color: isFinalPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Formula Container (User requested exact formula breakdown)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate_rounded, size: 15, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text(
                          'Formula: (Liquid Funds + Receivable) - Payable',
                          style: TextStyle(
                            color: Color(0xFFC7D2FE),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPrivate
                          ? '(•••••• Liquid + •••••• Lena) - •••••• Dena = ••••••'
                          : '(${currency.format(liquidFunds)} Liquid + ${currency.format(receivable)} Lena) - ${currency.format(payable)} Dena = ${currency.format(finalNetBalance)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF475569), height: 1),
              const SizedBox(height: 14),

              // Breakdown: Receivable, Payable, and Market Position
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      label: 'Total Receivable',
                      amount: mask(currency.format(stats.totalReceivable)),
                      count: '${stats.peopleToReceiveCount} people (Lena)',
                      color: const Color(0xFF34D399),
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  Container(width: 1, height: 44, color: const Color(0xFF475569)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildMetric(
                        label: 'Total Payable',
                        amount: mask(currency.format(stats.totalPayable)),
                        count: '${stats.peopleToPayCount} people (Dena)',
                        color: const Color(0xFFF87171),
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 44, color: const Color(0xFF475569)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _buildMetric(
                        label: 'Market Karza',
                        amount: mask(currency.format(stats.netLenDenPosition.abs())),
                        count: isNetPositive ? 'To Receive' : 'To Pay',
                        color: isNetPositive ? const Color(0xFF38BDF8) : const Color(0xFFFB923C),
                        icon: Icons.account_balance_wallet_rounded,
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
  }

  Widget _buildMetric({
    required String label,
    required String amount,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          count,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
      ],
    );
  }
}
