import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';
import '../../../../services/fitness_algorithms.dart';
import '../../../../services/unit_preference.dart';

class BodyMetricsPage extends StatefulWidget {
  const BodyMetricsPage({super.key});

  @override
  State<BodyMetricsPage> createState() => _BodyMetricsPageState();
}

class _BodyMetricsPageState extends State<BodyMetricsPage> {
  late final UnitPreference units;

  @override
  void initState() {
    super.initState();
    units = Get.find<UnitPreference>();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body metrics'),
        actions: [
          Obx(() => IconButton(
                tooltip: units.isImperial.value ? 'Using imperial' : 'Using metric',
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  await _showUnitPicker(context, units);
                  _refresh();
                },
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _showLogWeight(context, units);
          _refresh();
        },
        tooltip: 'Log weight',
        child: const Icon(Icons.add),
      ),
      body: _BodyMetricsBody(units: units, onRefresh: _refresh),
    );
  }

  Future<void> _showUnitPicker(BuildContext context, UnitPreference units) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Obx(() => AlertDialog(
            title: const Text('Unit system'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  title: const Text('Metric (kg, cm)'),
                  value: false,
                  groupValue: units.isImperial.value,
                  onChanged: (v) => units.setImperial(false),
                ),
                RadioListTile<bool>(
                  title: const Text('Imperial (lbs, in)'),
                  value: true,
                  groupValue: units.isImperial.value,
                  onChanged: (v) => units.setImperial(true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          )),
    );
  }
}

class _BodyMetricsBody extends StatelessWidget {
  const _BodyMetricsBody({required this.units, required this.onRefresh});
  final UnitPreference units;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = ObjectBox.instance.bodyMetricBox;
    final all = box.getAll()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final weights = all.where((m) => m.metric == 'weight').toList();
    final latestHeight = all.where((m) => m.metric == 'height').map((m) => m.value).firstOrNull;
    final latestAge = all.where((m) => m.metric == 'age').map((m) => m.value.toInt()).firstOrNull;
    final latestActivity = all.where((m) => m.metric == 'activity_level').map((m) => m.value.toInt()).firstOrNull;
    final latestSex = all.where((m) => m.metric == 'sex').map((m) => m.value.toInt()).firstOrNull;
    final latestWeight = weights.isNotEmpty ? weights.first.value : null;

    // Calculate TDEE if we have enough data.
    String? tdeeLabel;
    if (latestWeight != null && latestHeight != null && latestAge != null && latestSex != null) {
      final bmrVal = FitnessAlgorithms.bmr(
        weightKg: latestWeight,
        heightCm: latestHeight,
        age: latestAge,
        sex: latestSex,
      );
      final activity = latestActivity ?? 2;
      final tdeeVal = FitnessAlgorithms.tdee(bmrValue: bmrVal, activityLevel: activity);
      tdeeLabel = 'BMR: ${bmrVal.round()} kcal • TDEE: ${tdeeVal.round()} kcal/day';
    }

    final fmt = DateFormat.yMMMd();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _ProfileRow(label: 'Weight', value: latestWeight != null ? units.formatWeight(latestWeight) : '—'),
                _ProfileRow(label: 'Height', value: latestHeight != null ? units.formatHeight(latestHeight) : '—'),
                _ProfileRow(label: 'Age', value: latestAge?.toString() ?? '—'),
                _ProfileRow(label: 'Sex', value: latestSex == 0 ? 'Male' : latestSex == 1 ? 'Female' : '—'),
                _ProfileRow(label: 'Activity', value: _activityLabel(latestActivity)),
                if (tdeeLabel != null) ...[
                  const Divider(),
                  Text(tdeeLabel, style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Update profile'),
          onPressed: () async {
            await _showProfileSheet(context, units);
            onRefresh();
          },
        ),
        const SizedBox(height: 16),
        Text('Weight history', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (weights.isEmpty)
          const Text('No weight entries yet. Tap + to log.')
        else
          ...weights.map((w) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(units.formatWeight(w.value)),
                trailing: Text(fmt.format(w.recordedAt),
                    style: theme.textTheme.bodySmall),
                onLongPress: () {
                  box.remove(w.id);
                  (context as Element).markNeedsBuild();
                },
              )),
      ],
    );
  }

  String _activityLabel(int? level) {
    return switch (level) {
      1 => 'Sedentary',
      2 => 'Lightly active',
      3 => 'Moderately active',
      4 => 'Very active',
      5 => 'Extremely active',
      _ => '—',
    };
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

Future<void> _showLogWeight(BuildContext context, UnitPreference units) async {
  final ctrl = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom +
            MediaQuery.of(ctx).viewPadding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log weight', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Weight (${units.weightUnit})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null || val <= 0) return;
              final kg = units.weightToKg(val);
              ObjectBox.instance.bodyMetricBox.put(
                BodyMetric(metric: 'weight', value: kg),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showProfileSheet(BuildContext context, UnitPreference units) async {
  final box = ObjectBox.instance.bodyMetricBox;
  final all = box.getAll();
  final rawHeight = all.where((m) => m.metric == 'height').map((m) => m.value).firstOrNull;
  final heightCtrl = TextEditingController(
      text: rawHeight != null ? units.heightForDisplay(rawHeight).toStringAsFixed(0) : '');
  final ageCtrl = TextEditingController(
      text: all.where((m) => m.metric == 'age').map((m) => m.value.toInt().toString()).firstOrNull ?? '');
  int sex = all.where((m) => m.metric == 'sex').map((m) => m.value.toInt()).firstOrNull ?? 0;
  int activity = all.where((m) => m.metric == 'activity_level').map((m) => m.value.toInt()).firstOrNull ?? 2;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).viewPadding.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Profile', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: heightCtrl,
                decoration: InputDecoration(
                  labelText: 'Height (${units.heightUnit})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Male')),
                  ButtonSegment(value: 1, label: Text('Female')),
                ],
                selected: {sex},
                onSelectionChanged: (s) => setState(() => sex = s.first),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: activity,
                decoration: const InputDecoration(
                  labelText: 'Activity level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Sedentary')),
                  DropdownMenuItem(value: 2, child: Text('Lightly active')),
                  DropdownMenuItem(value: 3, child: Text('Moderately active')),
                  DropdownMenuItem(value: 4, child: Text('Very active')),
                  DropdownMenuItem(value: 5, child: Text('Extremely active')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => activity = v);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final h = double.tryParse(heightCtrl.text.trim());
                  final a = int.tryParse(ageCtrl.text.trim());
                  if (h != null) box.put(BodyMetric(metric: 'height', value: units.heightToCm(h)));
                  if (a != null) box.put(BodyMetric(metric: 'age', value: a.toDouble()));
                  box.put(BodyMetric(metric: 'sex', value: sex.toDouble()));
                  box.put(BodyMetric(metric: 'activity_level', value: activity.toDouble()));
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
