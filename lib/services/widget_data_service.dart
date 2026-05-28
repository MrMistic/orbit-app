import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/fitness_goal_controller.dart';
import '../controllers/workout_controller.dart';
import '../database/models.dart';
import '../database/object_box.dart';
import '../services/fitness_algorithms.dart';

/// Writes summary data to SharedPreferences so native Android widgets
/// can read it without starting the Flutter engine.
class WidgetDataService {
  static const _prefix = 'widget_';

  static Future<void> updateAll() async {
    final prefs = await SharedPreferences.getInstance();
    await _updateNextTodo(prefs);
    await _updateNextImportantDate(prefs);
    await _updateFitnessRecommendation(prefs);
    await _updateSleepSummary(prefs);
  }

  static Future<void> _updateNextTodo(SharedPreferences prefs) async {
    final box = ObjectBox.instance.todoBox;
    final todos = box.getAll().where((t) => !t.done).toList();

    // Sort: has due date first (earliest), then no-date by created.
    todos.sort((a, b) {
      if (a.dueDate != null && b.dueDate == null) return -1;
      if (a.dueDate == null && b.dueDate != null) return 1;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    if (todos.isEmpty) {
      await prefs.setString('${_prefix}next_todo_title', '');
      await prefs.setString('${_prefix}next_todo_due', '');
    } else {
      final t = todos.first;
      await prefs.setString('${_prefix}next_todo_title', t.title);
      await prefs.setString(
        '${_prefix}next_todo_due',
        t.dueDate?.toIso8601String() ?? '',
      );
    }
  }

  static Future<void> _updateNextImportantDate(SharedPreferences prefs) async {
    final box = ObjectBox.instance.importantDateBox;
    final dates = box.getAll();
    // Only show upcoming dates (today or future). Past one-time milestones
    // shouldn't appear in the widget.
    final upcoming = dates.where((d) => d.daysUntil >= 0).toList();
    if (upcoming.isEmpty) {
      await prefs.setString('${_prefix}next_date_title', '');
      await prefs.setInt('${_prefix}next_date_days', -1);
    } else {
      upcoming.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
      final d = upcoming.first;
      await prefs.setString('${_prefix}next_date_title', d.title);
      await prefs.setInt('${_prefix}next_date_days', d.daysUntil);
    }
  }

  static Future<void> _updateFitnessRecommendation(
      SharedPreferences prefs) async {
    final goalBox = ObjectBox.instance.fitnessGoalBox;
    final goals = goalBox.getAll().where((g) => !g.completed).toList();

    String rec = '';
    for (final goal in goals) {
      if (goal.goalType == 'strength' && goal.exerciseName != null) {
        final workoutBox = ObjectBox.instance.workoutBox;
        final workouts = workoutBox.getAll();
        final history = <ExerciseSet>[];
        for (final w in workouts) {
          for (final s in w.sets) {
            if (s.exerciseName.toLowerCase() ==
                goal.exerciseName!.toLowerCase()) {
              history.add(s);
            }
          }
        }
        if (history.isNotEmpty) {
          final lastWeight = history
              .where((s) => s.weight != null && s.weight! > 0)
              .fold<double>(0, (max, s) => s.weight! > max ? s.weight! : max);
          if (lastWeight > 0) {
            final achievedReps = history
                .reversed
                .take(5)
                .where((s) => s.reps != null)
                .map((s) => s.reps!)
                .toList();
            if (achievedReps.isNotEmpty) {
              final result = FitnessAlgorithms.nextSession(
                lastWeight: lastWeight,
                targetReps: 5,
                achievedReps: achievedReps,
              );
              rec =
                  '${goal.exerciseName}: ${result.weight.toStringAsFixed(0)} × ${result.reps}';
              break;
            }
          }
        }
      }
    }
    await prefs.setString('${_prefix}fitness_rec', rec);
  }

  static Future<void> _updateSleepSummary(SharedPreferences prefs) async {
    final box = ObjectBox.instance.sleepBox;
    final entries = box.getAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = entries.where((e) => e.bedtime.isAfter(cutoff)).toList();
    if (recent.isEmpty) {
      await prefs.setString('${_prefix}sleep_avg', '—');
    } else {
      final avg =
          recent.fold<double>(0, (s, e) => s + e.hoursSlept) / recent.length;
      await prefs.setString('${_prefix}sleep_avg', '${avg.toStringAsFixed(1)}h avg');
    }
  }
}
