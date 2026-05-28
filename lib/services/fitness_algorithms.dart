import 'dart:math' as math;

import '../database/models.dart';

/// Exercise science formulas and recommendation engine.
///
/// Sources:
/// - 1RM: Epley (1985), Brzycki (1993) — averaged for accuracy
/// - Volume: Prilepin's Chart (A.S. Prilepin, Soviet research)
/// - Overload: 2.5-5% weekly (2025 RCT, ACSM/NSCA guidelines)
/// - TDEE: Mifflin-St Jeor (1990) — most validated for healthy adults
/// - Cardio: 10% rule (ACSM position stand)
class FitnessAlgorithms {
  // ─── 1RM ESTIMATION ───

  /// Epley formula: 1RM = w × (1 + r/30). Best for moderate rep ranges (4-10).
  static double epley1RM(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Brzycki formula: 1RM = w × 36 / (37 - r). Best for lower rep ranges (1-6).
  static double brzycki1RM(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    if (reps >= 37) return weight * 2; // formula breaks down above 36 reps
    return weight * 36.0 / (37.0 - reps);
  }

  /// Average of Epley and Brzycki for a balanced estimate.
  static double estimated1RM(double weight, int reps) {
    if (reps <= 0 || reps == 1) return weight;
    return (epley1RM(weight, reps) + brzycki1RM(weight, reps)) / 2.0;
  }

  /// Compute the best estimated 1RM from a list of sets for a given exercise.
  static double? best1RM(List<ExerciseSet> sets) {
    double? best;
    for (final s in sets) {
      if (s.weight == null || s.reps == null) continue;
      if (s.weight! <= 0 || s.reps! <= 0) continue;
      final e = estimated1RM(s.weight!, s.reps!);
      if (best == null || e > best) best = e;
    }
    return best;
  }

  // ─── PRILEPIN'S CHART ───

  /// Returns recommended reps per set and total reps for a given intensity.
  static PrilepinZone prilepinZone(double intensityPercent) {
    if (intensityPercent >= 90) {
      return const PrilepinZone(
          repsPerSet: (1, 2), optimalTotal: 7, rangeTotal: (4, 10));
    } else if (intensityPercent >= 80) {
      return const PrilepinZone(
          repsPerSet: (2, 4), optimalTotal: 15, rangeTotal: (10, 20));
    } else if (intensityPercent >= 70) {
      return const PrilepinZone(
          repsPerSet: (3, 6), optimalTotal: 18, rangeTotal: (12, 24));
    } else {
      return const PrilepinZone(
          repsPerSet: (3, 6), optimalTotal: 24, rangeTotal: (18, 30));
    }
  }

  // ─── PROGRESSIVE OVERLOAD ───

  /// Recommends next session weight based on performance.
  /// If user hit target reps on all sets, increase by [incrementPercent].
  /// If user failed to hit target reps, keep same weight.
  static OverloadRecommendation nextSession({
    required double lastWeight,
    required int targetReps,
    required List<int> achievedReps, // reps per set from last session
    double incrementPercent = 0.025, // 2.5% default
    double minIncrement = 2.5, // minimum weight jump (lbs/kg)
  }) {
    final allHit = achievedReps.every((r) => r >= targetReps);
    if (allHit) {
      final increase = math.max(lastWeight * incrementPercent, minIncrement);
      final newWeight = lastWeight + increase;
      return OverloadRecommendation(
        weight: _roundToNearest(newWeight, minIncrement),
        reps: targetReps,
        reason: 'All sets hit $targetReps reps. Increase weight.',
      );
    } else {
      return OverloadRecommendation(
        weight: lastWeight,
        reps: targetReps,
        reason: 'Not all sets hit target. Repeat weight until consistent.',
      );
    }
  }

  /// Should the user deload this week? Simple rule: every [cycleWeeks] weeks.
  static bool shouldDeload(int weekNumber, {int cycleWeeks = 5}) {
    return weekNumber > 0 && weekNumber % cycleWeeks == 0;
  }

  /// Deload recommendation: reduce volume by 40-60%.
  static double deloadWeight(double currentWeight, {double factor = 0.6}) {
    return _roundToNearest(currentWeight * factor, 2.5);
  }

  // ─── TDEE / WEIGHT MANAGEMENT ───

  /// Mifflin-St Jeor BMR.
  /// [sex]: 0 = male, 1 = female.
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required int sex,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == 0 ? base + 5 : base - 161;
  }

  /// TDEE = BMR × activity factor.
  /// [activityLevel]: 1=sedentary, 2=light, 3=moderate, 4=active, 5=very active.
  static double tdee({
    required double bmrValue,
    required int activityLevel,
  }) {
    const factors = [1.2, 1.375, 1.55, 1.725, 1.9];
    final idx = (activityLevel - 1).clamp(0, 4);
    return bmrValue * factors[idx];
  }

  /// Caloric target for weight change.
  /// Returns daily calories. Negative deficit = weight loss.
  /// ~500 kcal deficit ≈ 0.5 kg/week loss.
  static double caloricTarget({
    required double tdeeValue,
    required double weeklyChangeKg, // positive = gain, negative = loss
  }) {
    // 1 kg fat ≈ 7700 kcal
    final dailyDelta = (weeklyChangeKg * 7700) / 7;
    return tdeeValue + dailyDelta;
  }

  /// Estimated weeks to reach target weight.
  static int weeksToGoal({
    required double currentWeight,
    required double targetWeight,
    required double weeklyChangeKg,
  }) {
    if (weeklyChangeKg.abs() < 0.01) return 999;
    final diff = (targetWeight - currentWeight).abs();
    return (diff / weeklyChangeKg.abs()).ceil();
  }

  // ─── CARDIO PROGRESSION ───

  /// 10% rule: max safe increase for next week.
  static double maxCardioIncrease(double currentWeeklyDistance) {
    return currentWeeklyDistance * 0.10;
  }

  /// Suggested next week distance.
  static double nextWeekDistance(double currentWeeklyDistance) {
    return currentWeeklyDistance * 1.10;
  }

  /// Pace in min/km from duration and distance.
  static double? pace({required double durationMin, required double distanceKm}) {
    if (distanceKm <= 0) return null;
    return durationMin / distanceKm;
  }

  // ─── HELPERS ───

  static double _roundToNearest(double value, double increment) {
    return (value / increment).round() * increment;
  }
}

class PrilepinZone {
  const PrilepinZone({
    required this.repsPerSet,
    required this.optimalTotal,
    required this.rangeTotal,
  });

  /// (min, max) reps per set.
  final (int, int) repsPerSet;

  /// Optimal total reps for the session.
  final int optimalTotal;

  /// (min, max) acceptable total reps.
  final (int, int) rangeTotal;
}

class OverloadRecommendation {
  const OverloadRecommendation({
    required this.weight,
    required this.reps,
    required this.reason,
  });

  final double weight;
  final int reps;
  final String reason;
}
