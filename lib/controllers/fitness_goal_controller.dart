import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/fitness_algorithms.dart';
import '../services/widget_refresh.dart';

class FitnessGoalController extends GetxController {
  final RxList<FitnessGoal> _items = <FitnessGoal>[].obs;

  List<FitnessGoal> get activeGoals =>
      _items.where((g) => !g.completed).toList();

  List<FitnessGoal> get completedGoals =>
      _items.where((g) => g.completed).toList();

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.fitnessGoalBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.fitnessGoalBox.getAll());
  }

  Future<void> add({
    required String goalType,
    required String title,
    String? exerciseName,
    double? targetValue,
    double? baselineValue,
    String? unit,
    DateTime? deadline,
  }) async {
    ObjectBox.instance.fitnessGoalBox.put(FitnessGoal(
      goalType: goalType,
      title: title.trim(),
      exerciseName: exerciseName,
      targetValue: targetValue,
      baselineValue: baselineValue,
      unit: unit,
      deadline: deadline,
    ));
    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> markCompleted(FitnessGoal goal) async {
    goal.completed = true;
    ObjectBox.instance.fitnessGoalBox.put(goal);
    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> remove(FitnessGoal goal) async {
    ObjectBox.instance.fitnessGoalBox.remove(goal.id);
    _reload();
    WidgetRefresh.refresh();
  }

  /// Progress percentage for a strength goal (based on current 1RM vs target).
  double? strengthProgress(FitnessGoal goal, double? current1RM) {
    if (goal.targetValue == null || goal.baselineValue == null) return null;
    if (current1RM == null) return 0;
    final total = goal.targetValue! - goal.baselineValue!;
    if (total <= 0) return 1.0;
    final progress = (current1RM - goal.baselineValue!) / total;
    return progress.clamp(0.0, 1.0);
  }

  /// Get recommendation for next workout based on a strength goal.
  OverloadRecommendation? getRecommendation(
    FitnessGoal goal,
    List<ExerciseSet> recentSets,
  ) {
    if (recentSets.isEmpty) return null;
    // Find the heaviest set from the most recent session.
    final lastWeight = recentSets
        .where((s) => s.weight != null && s.weight! > 0)
        .fold<double>(0, (max, s) => s.weight! > max ? s.weight! : max);
    if (lastWeight <= 0) return null;

    final targetReps = 5; // Default to 5x5 style
    final achievedReps = recentSets
        .where((s) => s.reps != null)
        .map((s) => s.reps!)
        .toList();
    if (achievedReps.isEmpty) return null;

    return FitnessAlgorithms.nextSession(
      lastWeight: lastWeight,
      targetReps: targetReps,
      achievedReps: achievedReps,
    );
  }
}
