import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/fitness_goal_controller.dart';
import '../../../../controllers/workout_controller.dart';
import '../../../../database/models.dart';
import '../../../../database/object_box.dart';
import '../../../../services/fitness_algorithms.dart';

class FitnessGoalsPage extends StatelessWidget {
  const FitnessGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(FitnessGoalController(), permanent: true);
    // Ensure workout controller is available for 1RM lookups.
    Get.put(WorkoutController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals & programming')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final active = c.activeGoals;
        final completed = c.completedGoals;
        if (active.isEmpty && completed.isEmpty) {
          return const Center(
            child: Text('No goals set. Tap + to create one.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (active.isNotEmpty) ...[
              const _SectionHeader(label: 'Active goals'),
              ...active.map((g) => _GoalTile(goal: g)),
            ],
            if (completed.isNotEmpty) ...[
              const _SectionHeader(label: 'Completed'),
              ...completed.map((g) => _GoalTile(goal: g)),
            ],
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});
  final FitnessGoal goal;

  @override
  Widget build(BuildContext context) {
    final gc = Get.find<FitnessGoalController>();
    final wc = Get.find<WorkoutController>();
    final theme = Theme.of(context);

    double? progress;
    String? recommendation;

    switch (goal.goalType) {
      case 'strength':
        if (goal.exerciseName != null) {
          final current1RM = wc.current1RM(goal.exerciseName!);
          progress = gc.strengthProgress(goal, current1RM);
          final history = wc.historyForExercise(goal.exerciseName!);
          if (history.isNotEmpty) {
            final recentSets =
                history.reversed.take(5).map((h) => h.$2).toList();
            final rec = gc.getRecommendation(goal, recentSets);
            if (rec != null) {
              recommendation =
                  '${rec.weight.toStringAsFixed(1)} × ${rec.reps} — ${rec.reason}';
            }
          }
        }
        break;

      case 'weight_loss':
      case 'weight_gain':
        if (goal.targetValue != null && goal.baselineValue != null) {
          // Use latest logged body weight from BodyMetric.
          final bodyMetrics = ObjectBox.instance.bodyMetricBox.getAll()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
          final latestWeight = bodyMetrics
              .where((m) => m.metric == 'weight')
              .map((m) => m.value)
              .firstOrNull;
          if (latestWeight != null) {
            final total =
                (goal.targetValue! - goal.baselineValue!).abs();
            final done =
                (latestWeight - goal.baselineValue!).abs();
            progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0;
          }
          // TDEE recommendation.
          final latestHeight = bodyMetrics
              .where((m) => m.metric == 'height')
              .map((m) => m.value)
              .firstOrNull;
          final latestAge = bodyMetrics
              .where((m) => m.metric == 'age')
              .map((m) => m.value.toInt())
              .firstOrNull;
          final latestSex = bodyMetrics
              .where((m) => m.metric == 'sex')
              .map((m) => m.value.toInt())
              .firstOrNull;
          final latestActivity = bodyMetrics
              .where((m) => m.metric == 'activity_level')
              .map((m) => m.value.toInt())
              .firstOrNull;

          if (latestWeight != null &&
              latestHeight != null &&
              latestAge != null &&
              latestSex != null) {
            final bmrVal = FitnessAlgorithms.bmr(
              weightKg: latestWeight,
              heightCm: latestHeight,
              age: latestAge,
              sex: latestSex,
            );
            final tdeeVal = FitnessAlgorithms.tdee(
              bmrValue: bmrVal,
              activityLevel: latestActivity ?? 2,
            );
            final dailyTarget = goal.goalType == 'weight_loss'
                ? tdeeVal - 500
                : tdeeVal + 500;
            final weeksLeft = latestWeight != null
                ? ((goal.targetValue! - latestWeight).abs() / 0.5).ceil()
                : null;
            recommendation =
                'Your TDEE: ~${tdeeVal.round()} kcal/day. '
                'Eat ~${dailyTarget.round()} kcal/day '
                '(${goal.goalType == 'weight_loss' ? '500 below' : '500 above'} maintenance). '
                '${weeksLeft != null ? 'Est. $weeksLeft week${weeksLeft == 1 ? '' : 's'} to goal.' : ''}';
          } else {
            recommendation =
                'Fill in your profile in Body Metrics (height, age, sex, activity) '
                'to get a personalized calorie target.';
          }
        }
        break;

      case 'cardio':
        if (goal.exerciseName != null) {
          final history = wc.historyForExercise(goal.exerciseName!);
          final unit = goal.unit ?? 'min/km';
          final bestPace = FitnessAlgorithms.currentBestPace(history: history, unit: unit);

          if (history.isEmpty || bestPace == null) {
            recommendation = 'Log a run to start getting pace targets.';
            break;
          }

          // Determine goal subtype from unit.
          if (unit == 'min' && goal.targetValue != null) {
            // Duration goal.
            final longestDuration = history
                .map((h) => h.$2.durationMinutes ?? 0.0)
                .fold<double>(0, (a, b) => a > b ? a : b);
            progress = FitnessAlgorithms.durationProgress(
              longestRun: longestDuration, targetDuration: goal.targetValue!,
            );
            final week = FitnessAlgorithms.currentTrainingWeek(goal.createdAt);
            final weekTarget = FitnessAlgorithms.weeklyDurationTarget(
              baselineDuration: goal.baselineValue ?? longestDuration,
              targetDuration: goal.targetValue!, weekNumber: week,
            );
            recommendation = 'Longest: ${longestDuration.toStringAsFixed(0)} min. '
                'This week: aim for ${weekTarget.toStringAsFixed(0)} min continuous.';
          } else if ((unit == 'km' || unit == 'mi') && goal.targetValue != null) {
            // Distance goal.
            final longestDist = history
                .map((h) => h.$2.distanceKm ?? 0.0)
                .fold<double>(0, (a, b) => a > b ? a : b);
            progress = FitnessAlgorithms.distanceProgress(
              longestRun: longestDist, targetDistance: goal.targetValue!,
            );
            final week = FitnessAlgorithms.currentTrainingWeek(goal.createdAt);
            final isTaper = week > 0 && week % 4 == 3;
            final weekTarget = FitnessAlgorithms.weeklyDistanceTarget(
              previousLongestRun: longestDist, targetDistance: goal.targetValue!, isTaperWeek: isTaper,
            );
            recommendation = 'Longest: ${longestDist.toStringAsFixed(1)} km. '
                'This week long run: ${weekTarget.toStringAsFixed(1)} km${isTaper ? ' (taper)' : ''}.';
          } else {
            // Pace goal.
            if (goal.targetValue != null && goal.baselineValue != null) {
              progress = FitnessAlgorithms.paceProgress(
                baselinePace: goal.baselineValue!, targetPace: goal.targetValue!, currentBestPace: bestPace,
              );
            }
            // Check for plateau.
            final weeklyPaces = <double>[];
            final now = DateTime.now();
            for (var w = 0; w < 4; w++) {
              final weekStart = now.subtract(Duration(days: (w + 1) * 7));
              final weekEnd = now.subtract(Duration(days: w * 7));
              double? weekBest;
              for (final (date, set) in history) {
                if (date.isAfter(weekStart) && date.isBefore(weekEnd)) {
                  final p = FitnessAlgorithms.computePace(
                    durationMinutes: set.durationMinutes ?? 0, distanceKm: set.distanceKm ?? 0, unit: unit,
                  );
                  if (p != null && (weekBest == null || p < weekBest)) weekBest = p;
                }
              }
              if (weekBest != null) weeklyPaces.add(weekBest);
            }

            if (FitnessAlgorithms.isInPlateau(weeklyBestPaces: weeklyPaces.reversed.toList())) {
              final interval = FitnessAlgorithms.generateIntervalSuggestion(
                targetPace: goal.targetValue ?? bestPace * 0.90, unit: unit,
              );
              recommendation = 'Plateau detected. Try: ${interval.displayText}';
            } else {
              final week = FitnessAlgorithms.currentTrainingWeek(goal.createdAt);
              final totalWeeks = goal.deadline != null
                  ? goal.deadline!.difference(goal.createdAt).inDays ~/ 7
                  : 12;
              final weekTarget = FitnessAlgorithms.weeklyPaceTarget(
                baselinePace: goal.baselineValue ?? bestPace,
                targetPace: goal.targetValue ?? bestPace * 0.90,
                weekNumber: week, totalWeeks: totalWeeks,
              );
              final pMin = weekTarget.floor();
              final pSec = ((weekTarget - pMin) * 60).round();
              final paceStr = '$pMin:${pSec.toString().padLeft(2, '0')}';
              final unitLabel = unit == 'min/mi' ? '/mi' : '/km';
              recommendation = 'This week: aim for $paceStr$unitLabel.';
            }
          }
        }
        break;

      case 'plyometric':
        if (goal.exerciseName != null) {
          final history = wc.historyForExercise(goal.exerciseName!);
          final phase = FitnessAlgorithms.currentPlyoPhase(goalCreatedAt: goal.createdAt);
          final phaseLabel = switch (phase) {
            PlyoPhase.accumulation => 'Accumulation',
            PlyoPhase.intensification => 'Intensification',
            PlyoPhase.deload => 'Deload',
          };

          // Determine if height-based or rep-based.
          final isHeightBased = goal.unit == 'in' || goal.unit == 'cm';

          if (isHeightBased) {
            final currentHeight = FitnessAlgorithms.currentBestHeight(history);
            if (goal.targetValue != null && goal.baselineValue != null && currentHeight != null) {
              progress = FitnessAlgorithms.plyoHeightProgress(
                baselineHeight: goal.baselineValue!, targetHeight: goal.targetValue!, currentBestHeight: currentHeight,
              );
            }

            // Strength prerequisite check.
            final bodyMetrics = ObjectBox.instance.bodyMetricBox.getAll()
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
            final bodyweight = bodyMetrics.where((m) => m.metric == 'weight').map((m) => m.value).firstOrNull;
            final squat1RM = wc.current1RM('Back Squat') ?? wc.current1RM('Front Squat');

            var classification = StrengthClassification.balanced;
            String classLabel = '';
            if (squat1RM != null && bodyweight != null) {
              classification = FitnessAlgorithms.classifyStrength(squat1RM: squat1RM, bodyweightKg: bodyweight);
              final ratio = (squat1RM / bodyweight).toStringAsFixed(1);
              classLabel = switch (classification) {
                StrengthClassification.strengthLimited => 'Squat: ${ratio}× BW — strength-limited. Focus: build strength.',
                StrengthClassification.balanced => 'Squat: ${ratio}× BW — balanced. Focus: power transfer.',
                StrengthClassification.powerLimited => 'Squat: ${ratio}× BW — power-limited. Focus: reactive work.',
              };
            }

            // Generate prescription.
            final prescription = FitnessAlgorithms.generatePrescription(
              phase: phase, classification: classification,
              goalExercise: goal.exerciseName!, currentMaxHeight: currentHeight, squat1RM: squat1RM,
            );
            final sessionDescriptions = prescription.sessions.map((s) {
              final intensityStr = s.intensity != null ? ' @ ${(s.intensity! * 100).round()}%' : '';
              final heightStr = s.heightTarget != null ? ' @ ${s.heightTarget!.toStringAsFixed(0)}in' : '';
              return '${s.exerciseName} ${s.sets}×${s.reps}$intensityStr$heightStr';
            }).join(', ');

            // Volume check.
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final weekSets = history
                .where((h) => h.$1.isAfter(weekAgo))
                .map((h) => h.$2)
                .toList();
            final vol = FitnessAlgorithms.volumeScore(weekSets);
            final volWarning = FitnessAlgorithms.isVolumeExcessive(actualVolume: vol, phase: phase)
                ? ' ⚠️ Volume high for this phase.'
                : '';

            // Strength nudge.
            final strengthExercises = ['Back Squat', 'Front Squat', 'Bulgarian Split Squat', 'RDL'];
            final hasRecentStrength = strengthExercises.any((ex) {
              final h = wc.historyForExercise(ex);
              return h.isNotEmpty && h.last.$1.isAfter(DateTime.now().subtract(const Duration(days: 14)));
            });
            final nudge = (!hasRecentStrength && classification != StrengthClassification.powerLimited)
                ? ' 💪 Add squats this week — strength is essential for jump gains.'
                : '';

            recommendation = '$phaseLabel: $sessionDescriptions$volWarning$nudge'
                '${classLabel.isNotEmpty ? '\n$classLabel' : ''}';
          } else {
            // Rep-based goal (existing behavior + phase info).
            if (history.isNotEmpty) {
              final maxReps = history.map((h) => h.$2.reps ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
              if (goal.targetValue != null && goal.baselineValue != null) {
                final total = goal.targetValue! - goal.baselineValue!;
                final done = maxReps - goal.baselineValue!;
                progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0;
              }
              recommendation = '$phaseLabel — Current max: $maxReps reps. '
                  '${phase == PlyoPhase.deload ? 'Deload week: light work only.' : 'Try adding 1-2 reps next session.'}';
            } else {
              recommendation = 'Log plyometric sessions to track progress.';
            }
          }
        }
        break;

      default:
        recommendation = 'Log exercises consistently to build data for recommendations.';
    }

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => gc.remove(goal),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.title, style: theme.textTheme.titleMedium),
                  ),
                  if (!goal.completed)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Mark completed',
                      onPressed: () => gc.markCompleted(goal),
                    ),
                ],
              ),
              if (goal.targetValue != null && goal.unit != null)
                Text(
                  'Target: ${goal.targetValue!.toStringAsFixed(1)} ${goal.unit}'
                  '${goal.baselineValue != null ? ' (from ${goal.baselineValue!.toStringAsFixed(1)})' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              if (goal.deadline != null)
                Text(
                  'Deadline: ${DateFormat.yMMMd().format(goal.deadline!)}',
                  style: theme.textTheme.bodySmall,
                ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text('${(progress * 100).round()}% progress',
                    style: theme.textTheme.bodySmall),
              ],
              if (recommendation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16,
                          color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next: $recommendation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showGoalSheet(BuildContext context, FitnessGoalController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _GoalSheetContent(controller: c),
  );
}

class _GoalSheetContent extends StatefulWidget {
  const _GoalSheetContent({required this.controller});
  final FitnessGoalController controller;

  @override
  State<_GoalSheetContent> createState() => _GoalSheetContentState();
}

class _GoalSheetContentState extends State<_GoalSheetContent> {
  final _titleCtrl = TextEditingController();
  final _exerciseCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'lbs');
  String _goalType = 'strength';
  DateTime? _deadline;

  // Auto-populated baseline (read-only display).
  double? _autoBaseline;
  String _autoBaselineLabel = '';

  @override
  void initState() {
    super.initState();
    _updateAutoBaseline();
  }

  void _updateAutoBaseline() {
    switch (_goalType) {
      case 'weight_loss' || 'weight_gain':
        final metrics = ObjectBox.instance.bodyMetricBox.getAll()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        final latest = metrics
            .where((m) => m.metric == 'weight')
            .map((m) => m.value)
            .firstOrNull;
        _autoBaseline = latest;
        _autoBaselineLabel = latest != null
            ? 'Current: ${latest.toStringAsFixed(1)} lbs'
            : 'Log weight in Body Metrics first';
        _unitCtrl.text = 'lbs';
        break;
      case 'strength':
        _autoBaseline = null;
        _autoBaselineLabel = '';
        _unitCtrl.text = 'lbs';
        break;
      case 'cardio':
        _autoBaseline = null;
        _autoBaselineLabel = '';
        _unitCtrl.text = 'min';
        break;
      case 'plyometric':
        _autoBaseline = null;
        _autoBaselineLabel = '';
        _unitCtrl.text = 'in';
        break;
    }
  }

  void _onExerciseChanged() {
    if (_goalType == 'strength' && _exerciseCtrl.text.trim().isNotEmpty) {
      final wc = Get.find<WorkoutController>();
      final current = wc.current1RM(_exerciseCtrl.text.trim());
      setState(() {
        _autoBaseline = current;
        _autoBaselineLabel = current != null
            ? 'Current 1RM: ${current.toStringAsFixed(1)} lbs'
            : 'No data yet';
      });
    } else if (_goalType == 'plyometric' && _exerciseCtrl.text.trim().isNotEmpty) {
      final wc = Get.find<WorkoutController>();
      final history = wc.historyForExercise(_exerciseCtrl.text.trim());
      if (history.isNotEmpty) {
        // For plyo, look at max weight (used as height) or max reps.
        final maxWeight = history
            .map((h) => h.$2.weight ?? 0.0)
            .fold<double>(0, (a, b) => a > b ? a : b);
        final maxReps = history
            .map((h) => h.$2.reps ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b);
        setState(() {
          if (maxWeight > 0) {
            _autoBaseline = maxWeight;
            _autoBaselineLabel = 'Current best: ${maxWeight.toStringAsFixed(1)} in';
          } else {
            _autoBaseline = maxReps.toDouble();
            _autoBaselineLabel = 'Current best: $maxReps reps';
          }
        });
      }
    } else if (_goalType == 'cardio' && _exerciseCtrl.text.trim().isNotEmpty) {
      final wc = Get.find<WorkoutController>();
      final history = wc.historyForExercise(_exerciseCtrl.text.trim());
      if (history.isNotEmpty) {
        // Best pace = min duration for >0 distance, or best distance.
        final withDistance = history.where((h) =>
            h.$2.distanceKm != null && h.$2.distanceKm! > 0 &&
            h.$2.durationMinutes != null && h.$2.durationMinutes! > 0);
        if (withDistance.isNotEmpty) {
          final bestPace = withDistance
              .map((h) => h.$2.durationMinutes! / h.$2.distanceKm!)
              .reduce((a, b) => a < b ? a : b);
          setState(() {
            _autoBaseline = bestPace;
            _autoBaselineLabel = 'Best pace: ${bestPace.toStringAsFixed(2)} min/km';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _exerciseCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New goal', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _goalType,
              decoration: const InputDecoration(
                labelText: 'Goal type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'strength', child: Text('Strength gain')),
                DropdownMenuItem(value: 'weight_loss', child: Text('Weight loss')),
                DropdownMenuItem(value: 'weight_gain', child: Text('Weight gain')),
                DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                DropdownMenuItem(value: 'plyometric', child: Text('Plyometric')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _goalType = v;
                    _updateAutoBaseline();
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _hintForType,
              ),
            ),
            // Exercise field (not for weight goals).
            if (_goalType != 'weight_loss' && _goalType != 'weight_gain') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _exerciseCtrl,
                decoration: InputDecoration(
                  labelText: _exerciseLabelForType,
                  hintText: _exerciseHintForType,
                ),
                onChanged: (_) => _onExerciseChanged(),
              ),
            ],
            // Auto baseline display.
            if (_autoBaselineLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_autoBaselineLabel, style: theme.textTheme.bodyMedium),
              ),
            ],
            const SizedBox(height: 8),
            // Target row.
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _targetCtrl,
                    decoration: InputDecoration(
                      labelText: _targetLabelForType,
                      hintText: _targetHintForType,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_deadline != null
                  ? 'Deadline: ${DateFormat.yMMMd().format(_deadline!)}'
                  : 'Set deadline (optional)'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _create,
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    );
  }

  String get _hintForType => switch (_goalType) {
    'strength' => 'e.g. Bench 225 lbs',
    'weight_loss' => 'e.g. Get to 180 lbs',
    'weight_gain' => 'e.g. Bulk to 200 lbs',
    'cardio' => 'e.g. 6:00 mile, 5K under 25 min',
    'plyometric' => 'e.g. 36 inch vertical',
    _ => '',
  };

  String get _exerciseLabelForType => switch (_goalType) {
    'strength' => 'Exercise',
    'cardio' => 'Activity',
    'plyometric' => 'Exercise',
    _ => 'Exercise',
  };

  String get _exerciseHintForType => switch (_goalType) {
    'strength' => 'e.g. Bench Press, Squat',
    'cardio' => 'e.g. Running, Cycling, Rowing',
    'plyometric' => 'e.g. Box Jump, Vertical Jump',
    _ => '',
  };

  String get _targetLabelForType => switch (_goalType) {
    'strength' => 'Target 1RM',
    'weight_loss' || 'weight_gain' => 'Target weight',
    'cardio' => 'Target (pace/distance/time)',
    'plyometric' => 'Target (height/reps)',
    _ => 'Target',
  };

  String get _targetHintForType => switch (_goalType) {
    'strength' => '225',
    'weight_loss' => '180',
    'weight_gain' => '200',
    'cardio' => '6.0 (min/mile) or 5.0 (km)',
    'plyometric' => '36 (inches) or 15 (reps)',
    _ => '',
  };

  void _create() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    widget.controller.add(
      goalType: _goalType,
      title: title,
      exerciseName: (_goalType == 'weight_loss' || _goalType == 'weight_gain')
          ? null
          : (_exerciseCtrl.text.trim().isEmpty ? null : _exerciseCtrl.text.trim()),
      targetValue: double.tryParse(_targetCtrl.text.trim()),
      baselineValue: _autoBaseline,
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      deadline: _deadline,
    );
    Navigator.pop(context);
  }
}
