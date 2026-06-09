import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Simple horizontal bar chart showing monthly burn by category.
class SubscriptionsBurnChart extends StatelessWidget {
  const SubscriptionsBurnChart({
    super.key,
    required this.monthlyTotal,
    required this.categoryBreakdown,
  });

  final double monthlyTotal;
  final Map<String, double> categoryBreakdown;

  @override
  Widget build(BuildContext context) {
    if (categoryBreakdown.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sorted = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: top.first.value * 1.2,
            barGroups: List.generate(top.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: top[i].value,
                    color: colors[i % colors.length],
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
              );
            }),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < top.length) {
                      final label = top[idx].key.length > 6
                          ? '${top[idx].key.substring(0, 6)}…'
                          : top[idx].key;
                      return Text(label,
                          style: theme.textTheme.bodySmall);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${top[groupIndex].key}\n\$${rod.toY.toStringAsFixed(2)}/mo',
                    TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
