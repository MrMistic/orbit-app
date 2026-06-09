import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/fitness_algorithms.dart';
import '../services/widget_refresh.dart';

class WorkoutController extends GetxController {
  final RxList<Workout> _items = <Workout>[].obs;

  /// Most recent first.
  List<Workout> get workouts {
    final list = List<Workout>.from(_items);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.workoutBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.workoutBox.getAll());
  }

  Future<Workout> create({
    required DateTime date,
    int? durationMinutes,
    String? notes,
    String type = 'strength',
    List<ExerciseSet> sets = const [],
    String muscleGroupsRaw = '',
  }) async {
    final workout = Workout(
      date: date,
      durationMinutes: durationMinutes,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      type: type,
      muscleGroupsRaw: muscleGroupsRaw,
    );
    for (var i = 0; i < sets.length; i++) {
      sets[i].order = i;
    }
    workout.sets.addAll(sets);
    ObjectBox.instance.workoutBox.put(workout);
    _reload();
    WidgetRefresh.refresh();
    return workout;
  }

  Future<void> updateWorkout(
    Workout workout, {
    required DateTime date,
    int? durationMinutes,
    String? notes,
    required String type,
    required List<ExerciseSet> sets,
  }) async {
    workout.date = date;
    workout.durationMinutes = durationMinutes;
    workout.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    workout.type = type;

    // Replace sets: use a transaction-safe approach.
    // 1. Collect old set IDs before modifying anything.
    final setBox = ObjectBox.instance.exerciseSetBox;
    final oldIds = workout.sets.map((s) => s.id).where((id) => id > 0).toList();

    // 2. First, put the new sets into the DB so they get IDs assigned.
    for (var i = 0; i < sets.length; i++) {
      sets[i].order = i;
      sets[i].id = 0; // ensure they're treated as new
    }
    setBox.putMany(sets);

    // 3. Now replace the relation and save the workout.
    workout.sets.clear();
    workout.sets.addAll(sets);
    ObjectBox.instance.workoutBox.put(workout);

    // 4. Finally, delete the old orphaned sets.
    if (oldIds.isNotEmpty) {
      setBox.removeMany(oldIds);
    }

    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> remove(Workout workout) async {
    final setBox = ObjectBox.instance.exerciseSetBox;
    final ids = workout.sets.map((s) => s.id).toList();
    if (ids.isNotEmpty) setBox.removeMany(ids);
    ObjectBox.instance.workoutBox.remove(workout.id);
    _reload();
    WidgetRefresh.refresh();
  }

  Workout? findById(int id) => ObjectBox.instance.workoutBox.get(id);

  /// Get all sets for a specific exercise across all workouts, sorted by date.
  List<(DateTime, ExerciseSet)> historyForExercise(String name) {
    final results = <(DateTime, ExerciseSet)>[];
    for (final w in _items) {
      for (final s in w.sets) {
        if (s.exerciseName.toLowerCase() == name.toLowerCase()) {
          results.add((w.date, s));
        }
      }
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results;
  }

  /// Estimated current 1RM for an exercise based on recent history.
  double? current1RM(String exerciseName) {
    final history = historyForExercise(exerciseName);
    if (history.isEmpty) return null;
    // Use last 28 days of data.
    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    final recent = history.where((h) => h.$1.isAfter(cutoff)).map((h) => h.$2).toList();
    if (recent.isNotEmpty) return FitnessAlgorithms.best1RM(recent);
    // Fall back to last 90 days if nothing in 28.
    final extendedCutoff = DateTime.now().subtract(const Duration(days: 90));
    final extended = history.where((h) => h.$1.isAfter(extendedCutoff)).map((h) => h.$2).toList();
    if (extended.isNotEmpty) return FitnessAlgorithms.best1RM(extended);
    // Nothing recent — return null so the UI prompts a fresh test.
    return null;
  }

  /// All distinct exercise names the user has logged.
  List<String> get allExerciseNames {
    final set = <String>{};
    for (final w in _items) {
      for (final s in w.sets) {
        set.add(s.exerciseName);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}
