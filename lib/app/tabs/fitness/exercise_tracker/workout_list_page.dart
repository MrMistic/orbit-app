import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/workout_controller.dart';
import '../../../../database/models.dart';
import 'workout_editor_page.dart';
import 'workout_volume_chart.dart';

class WorkoutListPage extends StatelessWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(WorkoutController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log workout'),
        onPressed: () => Get.to(() => const WorkoutEditorPage()),
      ),
      body: Obx(() {
        final list = c.workouts;
        if (list.isEmpty) {
          return const Center(
            child: Text('No workouts logged yet. Tap + to start.'),
          );
        }
        return Column(
          children: [
            WorkoutVolumeChart(workouts: list),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (_, i) => _WorkoutTile(workout: list[i]),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<WorkoutController>();
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    final setCount = workout.sets.length;

    return Dismissible(
      key: ValueKey(workout.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(workout),
      child: ListTile(
        onTap: () => Get.to(() => WorkoutEditorPage(existing: workout)),
        leading: _TypeIcon(type: workout.type),
        title: Text(
          workout.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${fmt.format(workout.date)} • $setCount set${setCount == 1 ? '' : 's'}'
          '${workout.durationMinutes != null ? ' • ${workout.durationMinutes} min' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (type) {
      'strength' => Icons.fitness_center,
      'cardio' => Icons.directions_run,
      'flexibility' => Icons.self_improvement,
      'plyometric' => Icons.height,
      _ => Icons.sports,
    };
    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Icon(icon, size: 20),
    );
  }
}
