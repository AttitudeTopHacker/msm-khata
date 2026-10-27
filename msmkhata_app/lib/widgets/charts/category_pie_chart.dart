import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/stats.dart';

class CategoryPieChart extends StatefulWidget {
  final List<CategoryBreakdown> categories;
  final double totalExpense;

  const CategoryPieChart({
    super.key,
    required this.categories,
    required this.totalExpense,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    if (widget.categories.isEmpty) {
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
              Icon(Icons.pie_chart_outline_rounded, size: 48, color: Color(0xFF64748B)),
              SizedBox(height: 10),
              Text(
                'Abhi koi category kharcha record nahi hai',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
                  Icon(Icons.donut_large_rounded, color: Color(0xFF818CF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Category-wise Kharcha',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.categories.length} Categories',
                  style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart with Center Total
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 55,
                    sections: List.generate(widget.categories.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final item = widget.categories[i];
                      final color = _parseColor(item.color);
                      final radius = isTouched ? 45.0 : 38.0;

                      return PieChartSectionData(
                        color: color,
                        value: item.totalAmount,
                        title: '${item.percentage.toStringAsFixed(0)}%',
                        radius: radius,
                        titleStyle: TextStyle(
                          fontSize: isTouched ? 14 : 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total Kharch',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(widget.totalExpense),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),

          // Category Legends & Percentages List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = widget.categories[index];
              final color = _parseColor(cat.color);
              final isHovered = index == _touchedIndex;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isHovered ? color.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cat.categoryName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      currency.format(cat.totalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cat.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
