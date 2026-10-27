import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../models/stats.dart';

class MonthlyTrendChart extends StatefulWidget {
  final List<MonthlyTrendItem> trends;

  const MonthlyTrendChart({super.key, required this.trends});

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart> {
  // Mode: 0 = Income vs Expense, 1 = Len-Den (Given vs Taken)
  int _viewMode = 0;

  String _formatMonth(String ym) {
    try {
      final parts = ym.split('-');
      if (parts.length >= 2) {
        final year = parts[0];
        final monthNum = int.parse(parts[1]);
        final dt = DateTime(int.parse(year), monthNum);
        return DateFormat('MMM yy').format(dt);
      }
    } catch (_) {}
    return ym;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactSimpleCurrency(locale: 'en_IN', name: '₹');

    if (widget.trends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFF64748B)),
              SizedBox(height: 10),
              Text(
                'No monthly trend data recorded yet',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Determine max Y value for scaling
    double maxY = 1000.0;
    for (final t in widget.trends) {
      if (_viewMode == 0) {
        maxY = math.max(maxY, math.max(t.totalIncome, t.totalExpense));
      } else {
        maxY = math.max(maxY, math.max(t.totalGiven, t.totalTaken));
      }
    }
    maxY = (maxY * 1.25).ceilToDouble();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Monthly Trend Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Segmented Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(index: 0, label: 'Income/Exp'),
                    _buildToggleItem(index: 1, label: 'Lent/Borrow'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Legend
          Row(
            children: [
              _buildLegend(
                color: _viewMode == 0 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                label: _viewMode == 0 ? 'Total Income' : 'Money Lent',
              ),
              const SizedBox(width: 16),
              _buildLegend(
                color: _viewMode == 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                label: _viewMode == 0 ? 'Total Expense' : 'Money Borrowed',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bar Chart
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = widget.trends[groupIndex];
                      final isFirst = rodIndex == 0;
                      final label = _viewMode == 0
                          ? (isFirst ? 'Income: ₹${item.totalIncome.toStringAsFixed(0)}' : 'Expense: ₹${item.totalExpense.toStringAsFixed(0)}')
                          : (isFirst ? 'Lent: ₹${item.totalGiven.toStringAsFixed(0)}' : 'Borrowed: ₹${item.totalTaken.toStringAsFixed(0)}');
                      return BarTooltipItem(
                        '${_formatMonth(item.month)}\n$label',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          currency.format(value),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < widget.trends.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _formatMonth(widget.trends[idx].month),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF334155),
                    strokeWidth: 0.8,
                  ),
                ),
                barGroups: List.generate(widget.trends.length, (idx) {
                  final t = widget.trends[idx];
                  final val1 = _viewMode == 0 ? t.totalIncome : t.totalGiven;
                  final val2 = _viewMode == 0 ? t.totalExpense : t.totalTaken;
                  final color1 = _viewMode == 0 ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
                  final color2 = _viewMode == 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

                  return BarChartGroupData(
                    x: idx,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: val1,
                        color: color1,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                      BarChartRodData(
                        toY: val2,
                        color: color2,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({required int index, required String label}) {
    final isSelected = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
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

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
