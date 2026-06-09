import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';

/// Weekly workout volume (total sets) bar chart for the last 8 weeks.
class WorkoutVolumeChart extends StatelessWidget {
  const WorkoutVolumeChart({super.key, required this.workouts});
  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build 8 weeks of data (most recent week last).
    final weeks = List.generate(8, (i) {
      // Week 0 = 8 weeks ago, week 7 = current week.
      final weeksAgo = 7 - i;
      final mondayOfWeek = today.subtract(Duration(days: today.weekday - 1 + weeksAgo * 7));
      final sundayOfWeek = mondayOfWeek.add(const Duration(days: 7));
      return (start: mondayOfWeek, end: sundayOfWeek);
    });

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < weeks.length; i++) {
      final w = weeks[i];
      final weekWorkouts = workouts.where((wo) {
        final d = DateTime(wo.date.year, wo.date.month, wo.date.day);
        return !d.isBefore(w.start) && d.isBefore(w.end);
      });
      final totalSets = weekWorkouts.fold<int>(0, (s, wo) => s + wo.sets.length);
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: totalSets.toDouble(),
            color: theme.colorScheme.primary,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    final maxY = bars.fold<double>(0, (m, b) => b.barRods.first.toY > m ? b.barRods.first.toY : m);
    if (maxY == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly volume (sets)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barGroups: bars,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < weeks.length) {
                          return Text(
                            DateFormat.Md().format(weeks[idx].start),
                            style: theme.textTheme.bodySmall,
                          );
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
                        '${rod.toY.toInt()} sets',
                        TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
