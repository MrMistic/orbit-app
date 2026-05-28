import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/cycle_controller.dart';
import '../../../../services/cycle_predictor.dart';

class CycleTrackerPage extends StatelessWidget {
  const CycleTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CycleController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Cycle tracker')),
      body: Obx(() {
        final pred = c.prediction.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PredictionCard(prediction: pred),
            const SizedBox(height: 16),
            _CalendarSection(
              controller: c,
              prediction: pred,
              futurePredictions: c.futurePredictions,
            ),
          ],
        );
      }),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});
  final CyclePrediction? prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (prediction == null) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Log period days to start getting predictions. '
            'Tap a day below and set the flow level.',
          ),
        ),
      );
    }
    final p = prediction!;
    final fmt = DateFormat.MMMd();
    final confPct = (p.confidence * 100).round();
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next period', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${fmt.format(p.nextPeriodStart)} '
              '(${fmt.format(p.nextPeriodWindow.start)} – '
              '${fmt.format(p.nextPeriodWindow.end)})',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Fertile window: ${fmt.format(p.fertileWindow.start)} – '
              '${fmt.format(p.fertileWindow.end)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Ovulation: ${fmt.format(p.ovulation)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Avg cycle: ${p.averageCycleLength.round()} days  •  '
              'Avg period: ${p.averagePeriodLength.round()} days',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Confidence: $confPct%  •  '
              '${p.cyclesAnalyzed} cycle${p.cyclesAnalyzed == 1 ? '' : 's'} analyzed',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSection extends StatefulWidget {
  const _CalendarSection({
    required this.controller,
    required this.prediction,
    required this.futurePredictions,
  });
  final CycleController controller;
  final CyclePrediction? prediction;
  final List<CyclePrediction> futurePredictions;

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  late DateTime _focusMonth;

  @override
  void initState() {
    super.initState();
    _focusMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(_focusMonth.year, _focusMonth.month, 1);
    final daysInMonth =
        DateTime(_focusMonth.year, _focusMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _focusMonth =
                    DateTime(_focusMonth.year, _focusMonth.month - 1);
              }),
            ),
            Text(
              DateFormat.yMMMM().format(_focusMonth),
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _focusMonth =
                    DateTime(_focusMonth.year, _focusMonth.month + 1);
              }),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _weekdayHeaders(theme),
        const SizedBox(height: 4),
        _buildGrid(theme, startWeekday, daysInMonth),
      ],
    );
  }

  Widget _weekdayHeaders(ThemeData theme) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(d, style: theme.textTheme.bodySmall),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGrid(ThemeData theme, int startWeekday, int daysInMonth) {
    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date =
          DateTime(_focusMonth.year, _focusMonth.month, day);
      cells.add(_DayCell(
        date: date,
        controller: widget.controller,
        prediction: widget.prediction,
        futurePredictions: widget.futurePredictions,
      ));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.controller,
    required this.prediction,
    required this.futurePredictions,
  });

  final DateTime date;
  final CycleController controller;
  final CyclePrediction? prediction;
  final List<CyclePrediction> futurePredictions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = controller.entryFor(date);
    final isToday = _isToday(date);
    final flow = entry?.flow ?? 0;

    // Check if this date falls within any predicted ovulation day.
    bool isOvulationDay = false;
    for (final p in futurePredictions) {
      if (date.year == p.ovulation.year &&
          date.month == p.ovulation.month &&
          date.day == p.ovulation.day) {
        isOvulationDay = true;
        break;
      }
    }

    // Determine background color based on state.
    Color? bg;
    if (flow > 0) {
      // Logged flow day — intensity by flow level.
      bg = theme.colorScheme.error.withValues(alpha: 0.2 + flow * 0.2);
    } else {
      // Check all future predictions for period window, ovulation, and fertile window.
      for (final p in futurePredictions) {
        if (p.nextPeriodWindow.contains(date)) {
          bg = theme.colorScheme.error.withValues(alpha: 0.1);
          break;
        } else if (date.year == p.ovulation.year &&
            date.month == p.ovulation.month &&
            date.day == p.ovulation.day) {
          bg = theme.colorScheme.primary.withValues(alpha: 0.25);
          break;
        } else if (p.fertileWindow.contains(date)) {
          bg = theme.colorScheme.primary.withValues(alpha: 0.12);
          break;
        }
      }
    }

    return GestureDetector(
      onTap: () => _showDaySheet(context),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isToday ? FontWeight.bold : null,
                color: flow > 0 ? theme.colorScheme.onErrorContainer : null,
              ),
            ),
            if (isOvulationDay && flow == 0)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _showDaySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _DaySheetContent(
        date: date,
        controller: controller,
      ),
    );
  }
}

class _DaySheetContent extends StatefulWidget {
  const _DaySheetContent({required this.date, required this.controller});
  final DateTime date;
  final CycleController controller;

  @override
  State<_DaySheetContent> createState() => _DaySheetContentState();
}

class _DaySheetContentState extends State<_DaySheetContent> {
  late int _flow;
  late TextEditingController _noteCtrl;
  late List<String> _symptoms;

  @override
  void initState() {
    super.initState();
    final entry = widget.controller.entryFor(widget.date);
    _flow = entry?.flow ?? 0;
    _noteCtrl = TextEditingController(text: entry?.note ?? '');
    _symptoms = List<String>.from(entry?.symptoms ?? []);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    final entry = widget.controller.entryFor(widget.date);

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
            Text(fmt.format(widget.date), style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Flow', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _FlowSelector(
              value: _flow,
              onChanged: (v) => setState(() => _flow = v),
            ),
            const SizedBox(height: 12),
            Text('Symptoms', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _SymptomChips(
              selected: _symptoms,
              onToggle: (s) => setState(() {
                if (_symptoms.contains(s)) {
                  _symptoms.remove(s);
                } else {
                  _symptoms.add(s);
                }
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (entry != null)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear day'),
                          content: const Text(
                            'Are you sure you want to clear all data for this day?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await widget.controller.clearDate(widget.date);
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Could not clear entry')),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Clear day'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.controller.setForDate(
                        widget.date,
                        flow: _flow,
                        note: _noteCtrl.text,
                        symptoms: _symptoms,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not save entry')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowSelector extends StatelessWidget {
  const _FlowSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['None', 'Light', 'Medium', 'Heavy'];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: List.generate(
        4,
        (i) => ButtonSegment(value: i, label: Text(_labels[i])),
      ),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _SymptomChips extends StatelessWidget {
  const _SymptomChips({required this.selected, required this.onToggle});
  final List<String> selected;
  final ValueChanged<String> onToggle;

  static const _common = [
    'Cramps',
    'Headache',
    'Bloating',
    'Fatigue',
    'Mood swings',
    'Back pain',
    'Nausea',
    'Acne',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _common
          .map((s) => FilterChip(
                label: Text(s),
                selected: selected.contains(s),
                onSelected: (_) => onToggle(s),
              ))
          .toList(),
    );
  }
}
