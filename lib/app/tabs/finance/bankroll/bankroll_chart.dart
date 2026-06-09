import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';

/// Cumulative P&L line chart for settled bets over time.
class BankrollChart extends StatelessWidget {
  const BankrollChart({super.key, required this.bets});
  final List<BetRecord> bets;

  @override
  Widget build(BuildContext context) {
    final settled = bets.where((b) => b.status != 'open').toList()
      ..sort((a, b) => (a.settledAt ?? a.placedAt).compareTo(b.settledAt ?? b.placedAt));
    if (settled.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final spots = <FlSpot>[];
    double cumulative = 0;
    for (var i = 0; i < settled.length; i++) {
      cumulative += settled[i].result;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }

    final isPositive = cumulative >= 0;
    final lineColor = isPositive ? Colors.green : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.min || value == meta.max || value == 0) {
                      return Text(
                        '\$${value.toInt()}',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(y: 0, color: Colors.grey.shade400, strokeWidth: 0.5),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: lineColor,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withAlpha(30),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final bet = settled[s.spotIndex];
                  final date = DateFormat.MMMd().format(bet.settledAt ?? bet.placedAt);
                  return LineTooltipItem(
                    '$date\n\$${s.y.toStringAsFixed(2)}',
                    TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
