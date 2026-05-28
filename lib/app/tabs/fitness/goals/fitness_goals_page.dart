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
          if (history.isNotEmpty) {
            // Sum distance from last 7 days for weekly total.
            final weekAgo =
                DateTime.now().subtract(const Duration(days: 7));
            final thisWeek = history
                .where((h) => h.$1.isAfter(weekAgo))
                .map((h) => h.$2.distanceKm ?? 0.0)
                .fold<double>(0, (a, b) => a + b);
            final nextWeek = thisWeek * 1.10;
            recommendation =
                'This week: ${thisWeek.toStringAsFixed(1)} km. '
                'Next week target: ${nextWeek.toStringAsFixed(1)} km (10% rule).';
            // Progress based on target distance/time.
            if (goal.targetValue != null && goal.baselineValue != null) {
              final best = history
                  .map((h) => h.$2.distanceKm ?? h.$2.durationMinutes ?? 0.0)
                  .fold<double>(0, (a, b) => a > b ? a : b);
              final total = (goal.targetValue! - goal.baselineValue!).abs();
              final done = (best - goal.baselineValue!).abs();
              progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0;
            }
          } else {
            recommendation = 'Start logging cardio to get progression advice.';
          }
        }
        break;

      case 'plyometric':
        if (goal.exerciseName != null) {
          final history = wc.historyForExercise(goal.exerciseName!);
          if (history.isNotEmpty) {
            final maxReps = history
                .map((h) => h.$2.reps ?? 0)
                .fold<int>(0, (a, b) => a > b ? a : b);
            recommendation =
                'Current max: $maxReps reps. Try adding 1-2 reps or an extra set next session.';
            if (goal.targetValue != null && goal.baselineValue != null) {
              final total = goal.targetValue! - goal.baselineValue!;
              final done = maxReps - goal.baselineValue!;
              progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0;
            }
          } else {
            recommendation = 'Log plyometric sessions to track progress.';
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
  final _baselineCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'lbs');
  String _goalType = 'strength';
  DateTime? _deadline;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _exerciseCtrl.dispose();
    _targetCtrl.dispose();
    _baselineCtrl.dispose();
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
                DropdownMenuItem(value: 'cardio', child: Text('Cardio improvement')),
                DropdownMenuItem(value: 'plyometric', child: Text('Plyometric')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _goalType = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Bench 225 lbs, Run 5K in 25 min',
              ),
            ),
            if (_goalType == 'strength' || _goalType == 'cardio') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _exerciseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exercise',
                  hintText: 'e.g. Bench Press, Running',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baselineCtrl,
                    decoration: const InputDecoration(labelText: 'Current'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetCtrl,
                    decoration: const InputDecoration(labelText: 'Target'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
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
              onPressed: () {
                widget.controller.add(
                  goalType: _goalType,
                  title: _titleCtrl.text,
                  exerciseName: _exerciseCtrl.text.trim().isEmpty
                      ? null
                      : _exerciseCtrl.text.trim(),
                  targetValue: double.tryParse(_targetCtrl.text.trim()),
                  baselineValue: double.tryParse(_baselineCtrl.text.trim()),
                  unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
                  deadline: _deadline,
                );
                Navigator.pop(context);
              },
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}
