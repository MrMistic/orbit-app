import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/workout_controller.dart';
import '../../../../data/exercise_names.dart';
import '../../../../database/models.dart';

class WorkoutEditorPage extends StatefulWidget {
  const WorkoutEditorPage({super.key, this.existing});
  final Workout? existing;

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  late DateTime _date;
  late String _type;
  late TextEditingController _durationCtrl;
  late TextEditingController _notesCtrl;
  final List<_ExerciseGroup> _groups = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _type = e?.type ?? 'strength';
    _durationCtrl =
        TextEditingController(text: e?.durationMinutes?.toString() ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');

    if (e != null) {
      // Group existing sets by exercise name.
      final sorted = e.sets.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final grouped = <String, List<ExerciseSet>>{};
      for (final s in sorted) {
        grouped.putIfAbsent(s.exerciseName, () => []).add(s);
      }
      for (final entry in grouped.entries) {
        _groups.add(_ExerciseGroup.fromSets(entry.key, entry.value));
      }
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addGroup() {
    setState(() {
      _groups.add(_ExerciseGroup(
        exerciseName: '',
        category: _type == 'cardio' ? 'cardio' : 'strength',
      ));
    });
  }

  void _removeGroup(int index) => setState(() => _groups.removeAt(index));

  Future<void> _save() async {
    final c = Get.find<WorkoutController>();
    final duration = int.tryParse(_durationCtrl.text.trim());
    final sets = <ExerciseSet>[];
    for (final g in _groups) {
      if (g.exerciseName.trim().isEmpty) continue;
      sets.addAll(g.toSets());
    }

    if (_isEdit) {
      await c.updateWorkout(
        widget.existing!,
        date: _date,
        durationMinutes: duration,
        notes: _notesCtrl.text,
        type: _type,
        sets: sets,
      );
    } else {
      await c.create(
        date: _date,
        durationMinutes: duration,
        notes: _notesCtrl.text,
        type: _type,
        sets: sets,
      );
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit workout' : 'Log workout'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGroup,
        icon: const Icon(Icons.add),
        label: const Text('Exercise'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Date + type row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat.yMMMd().format(_date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'strength', child: Text('Strength')),
                    DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                    DropdownMenuItem(
                        value: 'plyometric', child: Text('Plyo')),
                    DropdownMenuItem(
                        value: 'flexibility', child: Text('Flexibility')),
                    DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration (min)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_groups.isEmpty)
            Center(
              child: Text('Tap "Exercise" to add your first exercise.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            )
          else
            ..._groups.asMap().entries.map(
                  (e) => _ExerciseGroupCard(
                    group: e.value,
                    index: e.key,
                    onRemove: () => _removeGroup(e.key),
                    onChanged: () => setState(() {}),
                    workoutType: _type,
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise Group Card
// ---------------------------------------------------------------------------

class _ExerciseGroupCard extends StatelessWidget {
  const _ExerciseGroupCard({
    required this.group,
    required this.index,
    required this.onRemove,
    required this.onChanged,
    required this.workoutType,
  });

  final _ExerciseGroup group;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final String workoutType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCardio = group.category == 'cardio' || workoutType == 'cardio' ||
        group.category == 'flexibility' || workoutType == 'flexibility';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise name row
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    initialValue:
                        TextEditingValue(text: group.nameCtrl.text),
                    optionsBuilder: (v) {
                      final q = v.text.toLowerCase();
                      if (q.isEmpty) return const Iterable.empty();
                      return allExerciseNames
                          .where((n) => n.toLowerCase().contains(q));
                    },
                    onSelected: (s) {
                      group.nameCtrl.text = s;
                      onChanged();
                    },
                    fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                      ctrl.text = group.nameCtrl.text;
                      ctrl.addListener(() {
                        if (group.nameCtrl.text != ctrl.text) {
                          group.nameCtrl.text = ctrl.text;
                        }
                      });
                      return TextField(
                        controller: ctrl,
                        focusNode: focus,
                        decoration: InputDecoration(
                          labelText: 'Exercise',
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.list, size: 20),
                            onPressed: () =>
                                _showPicker(context, group, onChanged),
                          ),
                        ),
                        onChanged: (_) => onChanged(),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isCardio) ...[
              // Cardio: single row for duration + distance
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: group.durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min)',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: group.distanceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Distance (km)',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Strength: quick-add row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: group.weightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: group.repsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: group.setsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Show generated sets preview
              if (group.setCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${group.setCount} set${group.setCount == 1 ? '' : 's'} × '
                    '${group.repsCtrl.text} reps @ ${group.weightCtrl.text}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise picker (reused from before)
// ---------------------------------------------------------------------------

void _showPicker(
    BuildContext context, _ExerciseGroup group, VoidCallback onChanged) {
  showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Choose exercise',
                style: Theme.of(ctx).textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              children: [
                for (final entry in exerciseNames.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      entry.key,
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                    ),
                  ),
                  for (final name in entry.value)
                    ListTile(
                      dense: true,
                      title: Text(name),
                      onTap: () => Navigator.pop(ctx, name),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ).then((selected) {
    if (selected != null) {
      group.nameCtrl.text = selected;
      onChanged();
    }
  });
}

// ---------------------------------------------------------------------------
// Data model for an exercise group
// ---------------------------------------------------------------------------

class _ExerciseGroup {
  _ExerciseGroup({
    String exerciseName = '',
    this.category = 'strength',
  })  : nameCtrl = TextEditingController(text: exerciseName),
        weightCtrl = TextEditingController(),
        repsCtrl = TextEditingController(text: '8'),
        setsCtrl = TextEditingController(text: '3'),
        durationCtrl = TextEditingController(),
        distanceCtrl = TextEditingController();

  _ExerciseGroup.fromSets(String name, List<ExerciseSet> sets)
      : nameCtrl = TextEditingController(text: name),
        category = sets.first.category,
        weightCtrl = TextEditingController(
            text: sets.first.weight?.toString() ?? ''),
        repsCtrl = TextEditingController(
            text: sets.first.reps?.toString() ?? '8'),
        setsCtrl = TextEditingController(text: sets.length.toString()),
        durationCtrl = TextEditingController(
            text: sets.first.durationMinutes?.toString() ?? ''),
        distanceCtrl = TextEditingController(
            text: sets.first.distanceKm?.toString() ?? '');

  final TextEditingController nameCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController setsCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController distanceCtrl;
  String category;

  String get exerciseName => nameCtrl.text.trim();

  int get setCount => int.tryParse(setsCtrl.text.trim()) ?? 0;

  /// Generates ExerciseSet entities from this group.
  List<ExerciseSet> toSets() {
    if (category == 'cardio' || category == 'flexibility') {
      // Cardio/flexibility: single set with duration/distance.
      return [
        ExerciseSet(
          exerciseName: exerciseName,
          category: category,
          durationMinutes: double.tryParse(durationCtrl.text.trim()),
          distanceKm: double.tryParse(distanceCtrl.text.trim()),
        ),
      ];
    }
    // Strength/plyo: N sets with same weight and reps.
    final weight = double.tryParse(weightCtrl.text.trim());
    final reps = int.tryParse(repsCtrl.text.trim());
    final count = setCount.clamp(1, 20);
    return List.generate(
      count,
      (_) => ExerciseSet(
        exerciseName: exerciseName,
        category: category,
        weight: weight,
        reps: reps,
      ),
    );
  }
}
