import 'dart:math' as math;

import '../database/models.dart';

/// One past cycle: when bleeding started and how long until the next start.
class CycleStat {
  CycleStat({required this.start, required this.lengthDays});
  final DateTime start;
  final int lengthDays;
}

/// Forecast for upcoming cycle events.
class CyclePrediction {
  const CyclePrediction({
    required this.nextPeriodStart,
    required this.nextPeriodWindow,
    required this.fertileWindow,
    required this.ovulation,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.cyclesAnalyzed,
    required this.confidence,
  });

  /// Best-guess start date of the next period.
  final DateTime nextPeriodStart;

  /// Uncertainty window around [nextPeriodStart] (start..end inclusive).
  final DateRange nextPeriodWindow;

  /// Fertile window (typically days 10-15 of cycle).
  final DateRange fertileWindow;

  /// Predicted ovulation day.
  final DateTime ovulation;

  final double averageCycleLength;
  final double averagePeriodLength;
  final int cyclesAnalyzed;

  /// 0.0-1.0. Higher = more cycles logged + more consistent.
  final double confidence;
}

class DateRange {
  const DateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !dd.isBefore(s) && !dd.isAfter(e);
  }
}


/// Analyzes a user's flow log and produces predictions.
///
/// Algorithm overview:
///   1. Group consecutive flow days into "periods" (period = run of days with
///      flow > 0). A gap of 1 non-flow day inside a period is tolerated.
///   2. Compute cycle lengths (start to start) for adjacent periods.
///   3. Compute a weighted average cycle length, weighting recent cycles more.
///   4. Predict the next period start = last period start + average cycle.
///   5. Compute the prediction window from the standard deviation of recent
///      cycle lengths (smaller spread = tighter window).
///   6. Compute fertile window and ovulation by working back from the
///      next predicted period start (luteal phase ~14 days, fertile = 5 days
///      before ovulation through ovulation itself).
///   7. Chain predictions: use each predicted start as the anchor for the next
///      cycle, repeating until 12 months from today.
class CyclePredictor {
  /// Default cycle length when there is no data at all.
  static const _defaultCycleLength = 28;

  /// Default period length when only one period is logged.
  static const _defaultPeriodLength = 5;

  /// Most recent N cycles to use in averaging.
  static const _maxCycles = 12;

  /// Luteal phase length used to back-calculate ovulation.
  static const _lutealPhaseDays = 14;

  /// Builds [CycleStat]s by grouping flow days. Skips entries with flow == 0.
  static List<CycleStat> _detectPeriods(List<CycleEntry> entries) {
    if (entries.isEmpty) return [];
    final flowDays = entries
        .where((e) => e.flow > 0)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    if (flowDays.isEmpty) return [];

    // Group: a new period starts when the gap from the previous flow day is
    // greater than 2 days (allowing for one missed log day).
    final periodStarts = <DateTime>[];
    DateTime? prev;
    for (final d in flowDays) {
      if (prev == null || d.difference(prev).inDays > 2) {
        periodStarts.add(d);
      }
      prev = d;
    }

    final stats = <CycleStat>[];
    for (var i = 0; i < periodStarts.length - 1; i++) {
      final length = periodStarts[i + 1].difference(periodStarts[i]).inDays;
      // Filter out absurd values that suggest a logging gap (likely missed
      // an entire period).
      if (length < 15 || length > 60) continue;
      stats.add(CycleStat(start: periodStarts[i], lengthDays: length));
    }
    return stats;
  }

  /// Average length of bleeding (in days) for the last few periods.
  static double _averagePeriodLength(List<CycleEntry> entries) {
    if (entries.isEmpty) return _defaultPeriodLength.toDouble();
    final flowDays = entries
        .where((e) => e.flow > 0)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    if (flowDays.isEmpty) return _defaultPeriodLength.toDouble();

    // Group consecutive flow days (gap ≤ 2) into periods, count days each.
    final lengths = <int>[];
    int currentLen = 1;
    for (var i = 1; i < flowDays.length; i++) {
      final gap = flowDays[i].difference(flowDays[i - 1]).inDays;
      if (gap <= 2) {
        currentLen += 1;
      } else {
        lengths.add(currentLen);
        currentLen = 1;
      }
    }
    lengths.add(currentLen);
    if (lengths.isEmpty) return _defaultPeriodLength.toDouble();
    final recent = lengths.reversed.take(6).toList();
    final sum = recent.fold<int>(0, (a, b) => a + b);
    return sum / recent.length;
  }

  /// Recency-weighted average. Most recent cycle gets weight N, oldest gets 1.
  static double _weightedAverageLength(List<CycleStat> stats) {
    if (stats.isEmpty) return _defaultCycleLength.toDouble();
    final use = stats.length > _maxCycles
        ? stats.sublist(stats.length - _maxCycles)
        : stats;
    double weightedSum = 0;
    double weightTotal = 0;
    for (var i = 0; i < use.length; i++) {
      final weight = (i + 1).toDouble(); // newest = highest weight
      weightedSum += use[i].lengthDays * weight;
      weightTotal += weight;
    }
    return weightedSum / weightTotal;
  }

  /// Standard deviation of cycle lengths (population formula).
  static double _stdDev(List<CycleStat> stats, double mean) {
    if (stats.length < 2) return 0;
    final use = stats.length > _maxCycles
        ? stats.sublist(stats.length - _maxCycles)
        : stats;
    final sqSum = use.fold<double>(
        0, (acc, s) => acc + (s.lengthDays - mean) * (s.lengthDays - mean));
    return math.sqrt(sqSum / use.length);
  }

  /// Returns null when there is no data at all (caller handles empty UI).
  static CyclePrediction? predict(List<CycleEntry> entries) {
    final stats = _detectPeriods(entries);
    final periodLen = _averagePeriodLength(entries);

    // Need at least one period start to anchor predictions.
    final flowDays = entries
        .where((e) => e.flow > 0)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    if (flowDays.isEmpty) return null;

    final lastStart = stats.isNotEmpty
        ? stats.last.start.add(Duration(days: stats.last.lengthDays))
        : flowDays.last; // first period only — predict from its start

    // For users with only one period logged, anchor on that period's start.
    final anchor = stats.isNotEmpty ? lastStart : flowDays.first;

    final avg = _weightedAverageLength(stats);
    final std = _stdDev(stats, avg);

    final predicted = anchor.add(Duration(days: avg.round()));
    // Window expands with std; minimum +/- 1 day. Cap at +/- 4 days for sanity.
    final pad = std.clamp(1.0, 4.0).round();
    final window = DateRange(
      start: predicted.subtract(Duration(days: pad)),
      end: predicted.add(Duration(days: pad)),
    );

    final ovulation =
        predicted.subtract(const Duration(days: _lutealPhaseDays));
    final fertile = DateRange(
      start: ovulation.subtract(const Duration(days: 5)),
      end: ovulation,
    );

    // Confidence: scales with cycle count (cap at 8) and inverse spread.
    final cyclesScore = (stats.length / 8).clamp(0.0, 1.0);
    final stableScore = stats.length < 2 ? 0.0 : (1.0 - (std / 7).clamp(0.0, 1.0));
    final confidence = (cyclesScore * 0.6 + stableScore * 0.4).clamp(0.0, 1.0);

    return CyclePrediction(
      nextPeriodStart: predicted,
      nextPeriodWindow: window,
      fertileWindow: fertile,
      ovulation: ovulation,
      averageCycleLength: avg,
      averagePeriodLength: periodLen,
      cyclesAnalyzed: stats.length,
      confidence: confidence,
    );
  }

  /// Generates a list of predicted cycles covering up to [monthsAhead] months
  /// from today. Each cycle chains from the previous predicted start using the
  /// same weighted average cycle length.
  ///
  /// Returns an empty list if [predict] returns null (no data).
  static List<CyclePrediction> predictMultiple(
    List<CycleEntry> entries, {
    int monthsAhead = 12,
  }) {
    final first = predict(entries);
    if (first == null) return [];

    final cutoff = DateTime.now().add(Duration(days: monthsAhead * 30));
    final results = <CyclePrediction>[first];

    final avg = first.averageCycleLength;
    final stats = _detectPeriods(entries);
    final std = _stdDev(stats, avg);
    final pad = std.clamp(1.0, 4.0).round();

    var anchor = first.nextPeriodStart;

    while (true) {
      final nextStart = anchor.add(Duration(days: avg.round()));
      if (nextStart.isAfter(cutoff)) break;

      final window = DateRange(
        start: nextStart.subtract(Duration(days: pad)),
        end: nextStart.add(Duration(days: pad)),
      );
      final ovulation =
          nextStart.subtract(const Duration(days: _lutealPhaseDays));
      final fertile = DateRange(
        start: ovulation.subtract(const Duration(days: 5)),
        end: ovulation,
      );

      results.add(CyclePrediction(
        nextPeriodStart: nextStart,
        nextPeriodWindow: window,
        fertileWindow: fertile,
        ovulation: ovulation,
        averageCycleLength: first.averageCycleLength,
        averagePeriodLength: first.averagePeriodLength,
        cyclesAnalyzed: first.cyclesAnalyzed,
        confidence: first.confidence,
      ));

      anchor = nextStart;
    }

    return results;
  }
}

