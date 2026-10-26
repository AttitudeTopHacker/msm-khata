import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';

class NetPositionCard extends StatelessWidget {
  final DashboardStats stats;

  const NetPositionCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isNetPositive = stats.netLenDenPosition >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Len-Den Net Position',
                style: TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isNetPositive
                      ? const Color(0xFF059669).withOpacity(0.3)
                      : const Color(0xFFDC2626).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isNetPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isNetPositive ? 'Lena Hai' : 'Dena Hai',
                  style: TextStyle(
                    color: isNetPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currency.format(stats.netLenDenPosition.abs()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF475569), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: 'Total Lena Hai (Market)',
                  amount: currency.format(stats.totalReceivable),
                  count: '${stats.peopleToReceiveCount} people',
                  color: const Color(0xFF34D399),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(width: 1, height: 45, color: const Color(0xFF475569)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildMetric(
                    label: 'Total Dena Hai (Due)',
                    amount: currency.format(stats.totalPayable),
                    count: '${stats.peopleToPayCount} people',
                    color: const Color(0xFFF87171),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          count,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
      ],
    );
  }
}
