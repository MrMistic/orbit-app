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

  // ═══════════════════════════════════════════════════════════════════════
  // PACE ENGINE
  // ═══════════════════════════════════════════════════════════════════════

  static const _miToKm = 1.60934;

  /// Compute pace from duration and distance in the specified unit.
  static double? computePace({
    required double durationMinutes,
    required double distanceKm,
    required String unit,
  }) {
    if (durationMinutes <= 0 || distanceKm <= 0) return null;
    if (unit == 'min/mi') return durationMinutes / (distanceKm / _miToKm);
    return durationMinutes / distanceKm; // min/km
  }

  /// Find the user's current best (lowest) pace from sets within last 28 days.
  static double? currentBestPace({
    required List<(DateTime, ExerciseSet)> history,
    required String unit,
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    double? best;
    for (final (date, set) in history) {
      if (date.isBefore(cutoff)) continue;
      if (set.distanceKm == null || set.durationMinutes == null) continue;
      final p = computePace(
        durationMinutes: set.durationMinutes!,
        distanceKm: set.distanceKm!,
        unit: unit,
      );
      if (p != null && (best == null || p < best)) best = p;
    }
    return best;
  }

  /// Compute training week number from goal creation date.
  static int currentTrainingWeek(DateTime goalCreatedAt) {
    return DateTime.now().difference(goalCreatedAt).inDays ~/ 7;
  }

  /// Linear interpolation of pace targets with taper weeks.
  static double weeklyPaceTarget({
    required double baselinePace,
    required double targetPace,
    required int weekNumber,
    required int totalWeeks,
    int taperInterval = 4,
    bool omitTapers = false,
  }) {
    if (totalWeeks <= 0) return baselinePace;
    // Count how many taper weeks exist up to this point.
    int taperCount = 0;
    if (!omitTapers) {
      for (var w = 0; w <= weekNumber; w++) {
        if (w > 0 && w % taperInterval == taperInterval - 1) taperCount++;
      }
    }
    final trainingWeeks = totalWeeks - (omitTapers ? 0 : (totalWeeks ~/ taperInterval));
    if (trainingWeeks <= 0) return baselinePace;

    // Is this a taper week?
    final isTaper = !omitTapers && weekNumber > 0 && weekNumber % taperInterval == taperInterval - 1;
    final effectiveWeek = weekNumber - taperCount;

    if (isTaper && effectiveWeek > 0) {
      // Hold at previous training week's value.
      final prevProgress = (effectiveWeek - 1) / trainingWeeks;
      return baselinePace - (baselinePace - targetPace) * prevProgress.clamp(0.0, 1.0);
    }

    final progress = effectiveWeek / trainingWeeks;
    return baselinePace - (baselinePace - targetPace) * progress.clamp(0.0, 1.0);
  }

  /// Detect pace plateau: < 2% improvement over 3+ weeks.
  static bool isInPlateau({
    required List<double> weeklyBestPaces,
    double thresholdPercent = 0.02,
  }) {
    if (weeklyBestPaces.length < 3) return false;
    final recent = weeklyBestPaces.length > 3
        ? weeklyBestPaces.sublist(weeklyBestPaces.length - 3)
        : weeklyBestPaces;
    final first = recent.first;
    final last = recent.last;
    if (first <= 0) return false;
    // For pace, improvement = decrease. Check if (first - last) / first < threshold.
    return (first - last) / first <= thresholdPercent;
  }

  /// Generate interval suggestion for plateau breaking.
  static IntervalSuggestion generateIntervalSuggestion({
    required double targetPace,
    required String unit,
  }) {
    // Repeat pace: 10-15% faster (lower value) than target.
    final repeatPace = targetPace * 0.875; // ~12.5% faster
    // Use 400m repeats for pace goals under 5 min/km, 800m otherwise.
    final distance = targetPace < 5.0 ? 400 : 800;
    final repeats = distance == 400 ? 8 : 6;
    return IntervalSuggestion(
      repeatCount: repeats,
      repeatDistanceMeters: distance,
      repeatPace: repeatPace,
      restDurationSeconds: distance == 400 ? 90 : 120,
      unit: unit,
    );
  }

  /// Progress for a pace goal: (baseline - current) / (baseline - target).
  static double paceProgress({
    required double baselinePace,
    required double targetPace,
    required double currentBestPace,
  }) {
    final total = baselinePace - targetPace;
    if (total <= 0) return 1.0;
    return ((baselinePace - currentBestPace) / total).clamp(0.0, 1.0);
  }

  /// Progress for a duration goal.
  static double durationProgress({
    required double longestRun,
    required double targetDuration,
  }) {
    if (targetDuration <= 0) return 0;
    return (longestRun / targetDuration).clamp(0.0, 1.0);
  }

  /// Progress for a distance goal.
  static double distanceProgress({
    required double longestRun,
    required double targetDistance,
  }) {
    if (targetDistance <= 0) return 0;
    return (longestRun / targetDistance).clamp(0.0, 1.0);
  }

  /// Weekly duration target: increase by min(10%, 3 min) per week.
  static double weeklyDurationTarget({
    required double baselineDuration,
    required double targetDuration,
    required int weekNumber,
  }) {
    var current = baselineDuration;
    for (var w = 0; w < weekNumber; w++) {
      final increment = math.min(current * 0.10, 3.0);
      current += increment;
      if (current >= targetDuration) return targetDuration;
    }
    return current;
  }

  /// Weekly distance target: 10% rule with taper reduction.
  static double weeklyDistanceTarget({
    required double previousLongestRun,
    required double targetDistance,
    required bool isTaperWeek,
  }) {
    if (isTaperWeek) {
      return (previousLongestRun * 0.75).clamp(0, targetDistance); // 25% reduction
    }
    final target = previousLongestRun * 1.10;
    return target.clamp(0, targetDistance);
  }

  /// Polarized 80/20 training distribution.
  static TrainingDistribution polarizedDistribution({
    required double currentBestPace,
    required int weeklyFrequency,
    required String unit,
  }) {
    // 80% easy, 20% hard (round to whole sessions).
    final hardSessions = math.max(1, (weeklyFrequency * 0.2).round());
    final easySessions = weeklyFrequency - hardSessions;
    // Easy pace: 25-35% slower than best pace.
    final easyMin = currentBestPace * 1.25;
    final easyMax = currentBestPace * 1.35;
    return TrainingDistribution(
      easyRuns: easySessions,
      easyPaceRange: (easyMin, easyMax),
      intervalSessions: hardSessions > 1 ? 1 : hardSessions,
      tempoRuns: hardSessions > 1 ? hardSessions - 1 : 0,
      unit: unit,
    );
  }

  /// Check if easy runs are consistently too fast.
  static bool easyRunsTooFast({
    required List<(DateTime, ExerciseSet)> recentHistory,
    required double bestPace,
    required String unit,
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recentPaces = <double>[];
    for (final (date, set) in recentHistory) {
      if (date.isBefore(cutoff)) continue;
      final p = computePace(
        durationMinutes: set.durationMinutes ?? 0,
        distanceKm: set.distanceKm ?? 0,
        unit: unit,
      );
      if (p != null) recentPaces.add(p);
    }
    if (recentPaces.length < 3) return false;
    // If average pace is within 20% of best, easy runs are too fast.
    final avg = recentPaces.reduce((a, b) => a + b) / recentPaces.length;
    return avg < bestPace * 1.20;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLYO ENGINE
  // ═══════════════════════════════════════════════════════════════════════

  /// Contrast pairs: plyo exercise → strength exercise for PAP.
  static const _contrastPairs = <String, String>{
    'Box Jump': 'Back Squat',
    'Vertical Jump': 'Back Squat',
    'Broad Jump': 'Deadlift',
    'Depth Jump': 'Back Squat',
    'Drop Jump': 'Back Squat',
    'Plyo Push-Up': 'Bench Press',
    'Bounding': 'Bulgarian Split Squat',
    'Single-Leg Bound': 'Bulgarian Split Squat',
    'Trap Bar Jump': 'Trap Bar Deadlift',
    'Weighted Jump Squat': 'Back Squat',
  };

  /// Multi-modal exercise categories for vertical jump goals.
  static const _verticalJumpExercises = <String, List<String>>{
    'strength': ['Back Squat', 'Front Squat', 'Bulgarian Split Squat', 'RDL'],
    'power': ['Box Jump', 'Trap Bar Jump', 'Broad Jump', 'Weighted Jump Squat'],
    'reactive': ['Depth Jump', 'Pogo Hops', 'Drop Jump', 'Bounding'],
  };

  /// Intensity factors for volume scoring (foot-contact weighting).
  static const _plyoIntensityFactors = <String, double>{
    'Pogo Hops': 1.0, 'Ankle Bounces': 1.0, 'Jump Rope': 1.0,
    'Box Jump': 1.5, 'Broad Jump': 1.5, 'Bounding': 1.5,
    'Vertical Jump': 1.5, 'Tuck Jump': 1.5,
    'Weighted Jump Squat': 1.5, 'Trap Bar Jump': 1.5,
    'Depth Jump': 2.0, 'Drop Jump': 2.0, 'Single-Leg Bound': 2.0,
  };

  /// Determine current plyo phase from goal creation date (6-week cycle).
  static PlyoPhase currentPlyoPhase({
    required DateTime goalCreatedAt,
    int cycleWeeks = 6,
  }) {
    final days = DateTime.now().difference(goalCreatedAt).inDays;
    final weekInCycle = (days ~/ 7) % cycleWeeks;
    if (weekInCycle <= 2) return PlyoPhase.accumulation;
    if (weekInCycle <= 4) return PlyoPhase.intensification;
    return PlyoPhase.deload;
  }

  /// Volume score: sum of reps × intensity factor.
  static double volumeScore(List<ExerciseSet> plyoSets) {
    var score = 0.0;
    for (final s in plyoSets) {
      final factor = _plyoIntensityFactors[s.exerciseName] ?? 1.5;
      score += (s.reps ?? 0) * factor;
    }
    return score;
  }

  /// Recommended volume range (min, max foot contacts) for a phase.
  static (double, double) recommendedVolumeRange(PlyoPhase phase) {
    return switch (phase) {
      PlyoPhase.accumulation => (80, 120),
      PlyoPhase.intensification => (40, 80),
      PlyoPhase.deload => (0, 40),
    };
  }

  /// Check if volume exceeds phase recommendation by > 20%.
  static bool isVolumeExcessive({
    required double actualVolume,
    required PlyoPhase phase,
  }) {
    final (_, upper) = recommendedVolumeRange(phase);
    return actualVolume > upper * 1.2;
  }

  /// Compute Reactive Strength Index: height / ground contact time.
  static double? computeRSI({
    required double jumpHeightInches,
    required double groundContactSeconds,
  }) {
    if (jumpHeightInches <= 0 || groundContactSeconds <= 0) return null;
    return jumpHeightInches / groundContactSeconds;
  }

  /// Check if RSI has degraded > 15% from 4-week average.
  static bool isRSIDegraded({
    required double currentRSI,
    required double fourWeekAverageRSI,
    double threshold = 0.15,
  }) {
    if (fourWeekAverageRSI <= 0) return false;
    return currentRSI < fourWeekAverageRSI * (1 - threshold);
  }

  /// Get contrast training pair for a plyo exercise.
  static String? contrastPair(String plyoExercise) {
    return _contrastPairs[plyoExercise];
  }

  /// Classify athlete strength based on squat-to-bodyweight ratio.
  static StrengthClassification classifyStrength({
    required double squat1RM,
    required double bodyweightKg,
  }) {
    if (bodyweightKg <= 0) return StrengthClassification.balanced;
    final ratio = squat1RM / bodyweightKg;
    if (ratio < 1.5) return StrengthClassification.strengthLimited;
    if (ratio > 2.0) return StrengthClassification.powerLimited;
    return StrengthClassification.balanced;
  }

  /// Generate multi-modal training prescription for plyometric goals.
  static TrainingPrescription generatePrescription({
    required PlyoPhase phase,
    required StrengthClassification classification,
    required String goalExercise,
    required double? currentMaxHeight,
    required double? squat1RM,
  }) {
    final exercises = _verticalJumpExercises;
    final strengthEx = exercises['strength']!;
    final powerEx = exercises['power']!;
    final reactiveEx = exercises['reactive']!;

    final sessions = <PrescribedSession>[];
    final maxH = currentMaxHeight ?? 24.0;
    final squat = squat1RM ?? 135.0;

    switch (phase) {
      case PlyoPhase.accumulation:
        // Strength-focused: build force production base.
        if (classification == StrengthClassification.strengthLimited) {
          // 3 strength, 1 power
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[0], sets: 4, reps: 5, intensity: 0.80));
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[2], sets: 3, reps: 8, intensity: 0.70));
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[3], sets: 3, reps: 8, intensity: 0.70));
          sessions.add(PrescribedSession(category: 'power', exerciseName: powerEx[0], sets: 4, reps: 5, heightTarget: maxH * 0.65));
        } else {
          // 2 strength, 1 power, 1 reactive
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[0], sets: 4, reps: 5, intensity: 0.80));
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[3], sets: 3, reps: 8, intensity: 0.70));
          sessions.add(PrescribedSession(category: 'power', exerciseName: powerEx[0], sets: 5, reps: 3, heightTarget: maxH * 0.70));
          sessions.add(PrescribedSession(category: 'reactive', exerciseName: reactiveEx[1], sets: 3, reps: 10, heightTarget: null));
        }
        break;

      case PlyoPhase.intensification:
        if (classification == StrengthClassification.powerLimited) {
          // 0 strength, 2 reactive, 1 power
          sessions.add(PrescribedSession(category: 'reactive', exerciseName: reactiveEx[0], sets: 4, reps: 3, heightTarget: maxH * 0.85));
          sessions.add(PrescribedSession(category: 'reactive', exerciseName: reactiveEx[3], sets: 3, reps: 5, heightTarget: null));
          sessions.add(PrescribedSession(category: 'power', exerciseName: powerEx[1], sets: 4, reps: 3, heightTarget: maxH * 0.90));
        } else {
          // 1 strength, 2 power, 1 reactive
          sessions.add(PrescribedSession(category: 'strength', exerciseName: strengthEx[0], sets: 3, reps: 3, intensity: 0.90));
          sessions.add(PrescribedSession(category: 'power', exerciseName: powerEx[0], sets: 5, reps: 3, heightTarget: maxH * 0.85));
          sessions.add(PrescribedSession(category: 'power', exerciseName: powerEx[2], sets: 4, reps: 3, heightTarget: null));
          sessions.add(PrescribedSession(category: 'reactive', exerciseName: reactiveEx[0], sets: 4, reps: 3, heightTarget: maxH * 0.90));
        }
        break;

      case PlyoPhase.deload:
        // Light reactive only + test session.
        sessions.add(PrescribedSession(category: 'reactive', exerciseName: reactiveEx[1], sets: 2, reps: 8, heightTarget: null));
        sessions.add(PrescribedSession(category: 'power', exerciseName: goalExercise, sets: 1, reps: 3, heightTarget: maxH, intensity: 1.0));
        break;
    }

    return TrainingPrescription(sessions: sessions);
  }

  /// Progress for a height-based plyometric goal.
  static double plyoHeightProgress({
    required double baselineHeight,
    required double targetHeight,
    required double currentBestHeight,
  }) {
    final total = targetHeight - baselineHeight;
    if (total <= 0) return 1.0;
    return ((currentBestHeight - baselineHeight) / total).clamp(0.0, 1.0);
  }

  /// Get current best height from recent history (last 28 days).
  /// Uses weight field = height for plyo exercises.
  static double? currentBestHeight(List<(DateTime, ExerciseSet)> history) {
    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    double? best;
    for (final (date, set) in history) {
      if (date.isBefore(cutoff)) continue;
      if (set.weight != null && set.weight! > 0) {
        if (best == null || set.weight! > best) best = set.weight;
      }
    }
    // If nothing in last 28 days, fall back to last 90 days.
    if (best == null) {
      final extendedCutoff = DateTime.now().subtract(const Duration(days: 90));
      for (final (date, set) in history) {
        if (date.isBefore(extendedCutoff)) continue;
        if (set.weight != null && set.weight! > 0) {
          if (best == null || set.weight! > best) best = set.weight;
        }
      }
    }
    return best;
  }

  /// Get current best RSI from history (weight=height, durationMinutes=contact time in seconds).
  static double? currentBestRSI(List<(DateTime, ExerciseSet)> history) {
    double? best;
    for (final (_, set) in history) {
      if (set.weight != null && set.weight! > 0 &&
          set.durationMinutes != null && set.durationMinutes! > 0) {
        final rsi = set.weight! / set.durationMinutes!;
        if (best == null || rsi > best) best = rsi;
      }
    }
    return best;
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

// ═══════════════════════════════════════════════════════════════════════════
// PACE ENGINE — Cardio goal progression algorithms
// ═══════════════════════════════════════════════════════════════════════════
//
// Sources:
// - Polarized training: Stöggl & Sperlich (2014), Frontiers in Physiology
// - 80/20 rule: Seiler (2010), IJSPP
// - 10% weekly volume increase: ACSM position stand
// - Interval training: Billat et al. (2001), VO₂max intervals
// - Plateau threshold: 2% improvement standard (coaching consensus)

/// Plyometric periodization phase within a 6-week cycle.
enum PlyoPhase {
  accumulation,    // Weeks 0–2: high volume, moderate intensity (60-75% max)
  intensification, // Weeks 3–4: low volume, high intensity (80-95% max)
  deload,          // Week 5: recovery (50% volume, 60% intensity)
}

/// Athlete strength classification for plyometric programming.
enum StrengthClassification {
  strengthLimited, // Squat < 1.5× BW: prioritize strength foundation
  balanced,        // Squat 1.5–2.0× BW: standard phased program
  powerLimited,    // Squat > 2.0× BW: prioritize reactive/elastic work
}

/// A structured interval workout suggestion for plateau breaking.
class IntervalSuggestion {
  const IntervalSuggestion({
    required this.repeatCount,
    required this.repeatDistanceMeters,
    required this.repeatPace,
    required this.restDurationSeconds,
    required this.unit,
  });

  final int repeatCount;
  final int repeatDistanceMeters;
  final double repeatPace;
  final int restDurationSeconds;
  final String unit;

  String get displayText {
    final paceMin = repeatPace.floor();
    final paceSec = ((repeatPace - paceMin) * 60).round();
    final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    final distStr = repeatDistanceMeters >= 1000
        ? '${(repeatDistanceMeters / 1000).toStringAsFixed(1)}km'
        : '${repeatDistanceMeters}m';
    final unitLabel = unit == 'min/mi' ? 'mi' : 'km';
    return '$repeatCount × $distStr at $paceStr/$unitLabel, ${restDurationSeconds}s rest';
  }
}

/// Polarized training plan for a given week.
class TrainingDistribution {
  const TrainingDistribution({
    required this.easyRuns,
    required this.easyPaceRange,
    required this.intervalSessions,
    required this.tempoRuns,
    required this.unit,
  });

  final int easyRuns;
  final (double, double) easyPaceRange;
  final int intervalSessions;
  final int tempoRuns;
  final String unit;
}

/// A single prescribed training session in a multi-modal plyo program.
class PrescribedSession {
  const PrescribedSession({
    required this.category,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.intensity,
    this.heightTarget,
  });

  final String category; // "strength", "power", "reactive"
  final String exerciseName;
  final int sets;
  final int reps;
  final double? intensity; // % of 1RM or max height
  final double? heightTarget; // target height in inches (plyo)
}

/// A weekly multi-modal training plan for plyometric goals.
class TrainingPrescription {
  const TrainingPrescription({required this.sessions});
  final List<PrescribedSession> sessions;
}
