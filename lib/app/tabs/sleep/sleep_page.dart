import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SleepController extends GetxController {
  final _box = ObjectBox.instance.sleepBox;

  final entries = <SleepEntry>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) => b.bedtime.compareTo(a.bedtime));
    entries.assignAll(all);
  }

  void add({
    required DateTime bedtime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  }) {
    _box.put(SleepEntry(
      bedtime: bedtime,
      wakeTime: wakeTime,
      quality: quality,
      notes: notes,
    ));
    _load();
  }

  void remove(SleepEntry entry) {
    _box.remove(entry.id);
    _load();
  }

  /// Average hours slept in the last 7 days.
  double? get avgHoursThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent =
        entries.where((e) => e.bedtime.isAfter(cutoff)).toList();
    if (recent.isEmpty) return null;
    final total = recent.fold<double>(0, (s, e) => s + e.hoursSlept);
    return total / recent.length;
  }

  /// Average quality in the last 7 days.
  double? get avgQualityThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = entries
        .where((e) => e.bedtime.isAfter(cutoff) && e.quality != null)
        .toList();
    if (recent.isEmpty) return null;
    final total = recent.fold<int>(0, (s, e) => s + e.quality!);
    return total / recent.length;
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SleepController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSleepSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.entries;
        return Column(
          children: [
            // Summary card
            _SummaryCard(controller: c),
            // Weekly bar chart
            _WeeklyChart(controller: c),
            // List
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('No entries yet. Tap + to log sleep.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _SleepTile(entry: list[i], controller: c),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});
  final SleepController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final avgHours = controller.avgHoursThisWeek;
      final avgQuality = controller.avgQualityThisWeek;
      if (avgHours == null && avgQuality == null) {
        return const SizedBox.shrink();
      }
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (avgHours != null)
                Column(
                  children: [
                    Text(
                      '${avgHours.toStringAsFixed(1)}h',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('avg this week',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              if (avgQuality != null)
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          avgQuality.toStringAsFixed(1),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                      ],
                    ),
                    Text('avg quality',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _SleepTile extends StatelessWidget {
  const _SleepTile({required this.entry, required this.controller});
  final SleepEntry entry;
  final SleepController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.MMMd();
    final timeFmt = DateFormat.jm();

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(entry),
      child: ListTile(
        title: Text(
          '${dateFmt.format(entry.bedtime)} — ${entry.hoursSlept.toStringAsFixed(1)} hrs',
        ),
        subtitle: Text(
          [
            '${timeFmt.format(entry.bedtime)} → ${timeFmt.format(entry.wakeTime)}',
            if (entry.notes != null && entry.notes!.isNotEmpty) entry.notes!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: entry.quality != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < entry.quality! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showSleepSheet(BuildContext context, SleepController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SleepSheetContent(controller: c),
  );
}

class _SleepSheetContent extends StatefulWidget {
  const _SleepSheetContent({required this.controller});
  final SleepController controller;

  @override
  State<_SleepSheetContent> createState() => _SleepSheetContentState();
}

class _SleepSheetContentState extends State<_SleepSheetContent> {
  late DateTime _bedtime;
  late DateTime _wakeTime;
  int _quality = 3;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default: last night 11pm to this morning 7am
    _bedtime = DateTime(now.year, now.month, now.day - 1, 23, 0);
    _wakeTime = DateTime(now.year, now.month, now.day, 7, 0);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat.jm();
    final dateFmt = DateFormat.MMMd();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log sleep', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // Bedtime
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bedtime'),
              subtitle: Text(
                  '${dateFmt.format(_bedtime)} ${timeFmt.format(_bedtime)}'),
              trailing: const Icon(Icons.bedtime_outlined),
              onTap: () => _pickTime(isBedtime: true),
            ),
            // Wake time
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wake time'),
              subtitle: Text(
                  '${dateFmt.format(_wakeTime)} ${timeFmt.format(_wakeTime)}'),
              trailing: const Icon(Icons.wb_sunny_outlined),
              onTap: () => _pickTime(isBedtime: false),
            ),
            const SizedBox(height: 8),
            // Quality
            Text('Quality', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: List.generate(
                5,
                (i) => ButtonSegment(
                  value: i + 1,
                  label: Text('${i + 1}'),
                ),
              ),
              selected: {_quality},
              onSelectionChanged: (v) =>
                  setState(() => _quality = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.controller.add(
                  bedtime: _bedtime,
                  wakeTime: _wakeTime,
                  quality: _quality,
                  notes: _notesCtrl.text.trim().isNotEmpty
                      ? _notesCtrl.text.trim()
                      : null,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isBedtime}) async {
    final current = isBedtime ? _bedtime : _wakeTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isBedtime) {
        _bedtime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.controller});
  final SleepController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = controller.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    // Build data for the last 7 days.
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      // Assign sleep to the bedtime date ("Friday night's sleep" = Friday's bar).
      final dayEntries = entries.where((e) {
        final bedDay = DateTime(e.bedtime.year, e.bedtime.month, e.bedtime.day);
        return bedDay == day;
      }).toList();
      final hours = dayEntries.isEmpty
          ? 0.0
          : dayEntries.fold<double>(0, (s, e) => s + e.hoursSlept) /
              dayEntries.length;
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: hours,
            color: theme.colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    final dayLabels = days.map((d) => DateFormat.E().format(d).substring(0, 2)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 140,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 12,
            barGroups: bars,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == 4 || value == 8 || value == 12) {
                      return Text('${value.toInt()}h',
                          style: theme.textTheme.bodySmall);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < dayLabels.length) {
                      return Text(dayLabels[idx],
                          style: theme.textTheme.bodySmall);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)}h',
                    TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
