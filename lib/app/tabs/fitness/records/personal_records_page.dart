import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/fitness_goal_controller.dart';
import '../../../../controllers/workout_controller.dart';
import '../../../../services/fitness_algorithms.dart';

class PersonalRecordsPage extends StatelessWidget {
  const PersonalRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(WorkoutController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal records')),
      body: Obx(() {
        final exercises = c.allExerciseNames;
        if (exercises.isEmpty) {
          return const Center(
            child: Text('Log some workouts to see your records here.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: exercises.length,
          itemBuilder: (_, i) => _RecordTile(
            exerciseName: exercises[i],
            controller: c,
          ),
        );
      }),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.exerciseName, required this.controller});
  final String exerciseName;
  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = controller.historyForExercise(exerciseName);
    if (history.isEmpty) return const SizedBox.shrink();

    // Find max weight, max reps, best estimated 1RM.
    double? maxWeight;
    int? maxReps;
    double? best1RM;
    DateTime? best1RMDate;
    double? maxDistance;
    double? maxDuration;

    for (final (date, set) in history) {
      if (set.weight != null && (maxWeight == null || set.weight! > maxWeight)) {
        maxWeight = set.weight;
      }
      if (set.reps != null && (maxReps == null || set.reps! > maxReps)) {
        maxReps = set.reps;
      }
      if (set.weight != null && set.reps != null && set.weight! > 0 && set.reps! > 0) {
        final e = FitnessAlgorithms.estimated1RM(set.weight!, set.reps!);
        if (best1RM == null || e > best1RM) {
          best1RM = e;
          best1RMDate = date;
        }
      }
      if (set.distanceKm != null &&
          (maxDistance == null || set.distanceKm! > maxDistance)) {
        maxDistance = set.distanceKm;
      }
      if (set.durationMinutes != null &&
          (maxDuration == null || set.durationMinutes! > maxDuration)) {
        maxDuration = set.durationMinutes;
      }
    }

    final isCardio = maxDistance != null || (maxWeight == null && maxDuration != null);
    final fmt = DateFormat.yMMMd();

    return ExpansionTile(
      title: Text(exerciseName, style: theme.textTheme.titleMedium),
      subtitle: Text(
        isCardio
            ? '${history.length} session${history.length == 1 ? '' : 's'}'
            : 'Est. 1RM: ${best1RM?.toStringAsFixed(1) ?? '—'}',
        style: theme.textTheme.bodySmall,
      ),
      children: [
        if (maxWeight != null)
          _StatRow(label: 'Max weight', value: maxWeight.toStringAsFixed(1)),
        if (maxReps != null)
          _StatRow(label: 'Max reps (single set)', value: maxReps.toString()),
        if (best1RM != null)
          _StatRow(
            label: 'Best estimated 1RM',
            value: best1RM.toStringAsFixed(1),
            subtitle: best1RMDate != null ? fmt.format(best1RMDate) : null,
          ),
        if (maxDistance != null)
          _StatRow(label: 'Longest distance', value: '${maxDistance.toStringAsFixed(2)} km'),
        if (maxDuration != null)
          _StatRow(label: 'Longest duration', value: '${maxDuration.toStringAsFixed(1)} min'),
        _StatRow(label: 'Total sessions', value: '${history.length}'),
        if (best1RM != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Set strength goal'),
              onPressed: () => _showGoalFromPR(
                context,
                exerciseName: exerciseName,
                current1RM: best1RM!,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.subtitle});
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: theme.textTheme.titleSmall),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

void _showGoalFromPR(
  BuildContext context, {
  required String exerciseName,
  required double current1RM,
}) {
  final targetCtrl = TextEditingController();
  final gc = Get.put(FitnessGoalController(), permanent: true);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom +
            MediaQuery.of(ctx).viewPadding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Strength goal', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '$exerciseName — current est. 1RM: ${current1RM.toStringAsFixed(1)}',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Target 1RM',
                hintText: 'e.g. 225',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final target = double.tryParse(targetCtrl.text.trim());
                if (target == null || target <= current1RM) {
                  Get.snackbar(
                    'Invalid target',
                    'Target must be higher than your current 1RM.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                gc.add(
                  goalType: 'strength',
                  title: '$exerciseName ${target.toStringAsFixed(0)}',
                  exerciseName: exerciseName,
                  targetValue: target,
                  baselineValue: current1RM,
                  unit: 'lbs',
                );
                Navigator.pop(ctx);
                Get.snackbar(
                  'Goal created',
                  '$exerciseName → ${target.toStringAsFixed(0)} lbs',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    ),
  );
}
