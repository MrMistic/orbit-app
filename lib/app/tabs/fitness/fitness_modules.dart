import 'package:flutter/material.dart';

import 'body_metrics/body_metrics_page.dart';
import 'exercise_tracker/workout_list_page.dart';
import 'goals/fitness_goals_page.dart';
import 'records/personal_records_page.dart';

class FitnessSubmodule {
  const FitnessSubmodule({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.pageBuilder,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder pageBuilder;
}

class FitnessRegistry {
  static final List<FitnessSubmodule> all = [
    FitnessSubmodule(
      id: 'exercise_tracker',
      label: 'Exercise tracker',
      subtitle: 'Log workouts, track sets and progress',
      icon: Icons.fitness_center,
      pageBuilder: (_) => const WorkoutListPage(),
    ),
    FitnessSubmodule(
      id: 'records',
      label: 'Personal records',
      subtitle: 'Max weight, reps, and estimated 1RM',
      icon: Icons.emoji_events_outlined,
      pageBuilder: (_) => const PersonalRecordsPage(),
    ),
    FitnessSubmodule(
      id: 'body_metrics',
      label: 'Body metrics',
      subtitle: 'Weight, height, TDEE calculator',
      icon: Icons.monitor_weight_outlined,
      pageBuilder: (_) => const BodyMetricsPage(),
    ),
    FitnessSubmodule(
      id: 'goals',
      label: 'Goals & programming',
      subtitle: 'Set targets, get recommendations',
      icon: Icons.flag_outlined,
      pageBuilder: (_) => const FitnessGoalsPage(),
    ),
  ];
}
