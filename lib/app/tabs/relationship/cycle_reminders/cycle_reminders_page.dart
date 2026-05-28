import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../controllers/cycle_reminders_controller.dart';
import '../../../../database/models.dart';

class CycleRemindersPage extends StatelessWidget {
  const CycleRemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CycleRemindersController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Cycle-aware reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.reminders;
        if (list.isEmpty) {
          return _EmptyState(controller: c);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _ReminderTile(reminder: list[i]),
        );
      }),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.controller});
  final CycleRemindersController controller;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = CycleRemindersController.presets;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No reminders set', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Get gentle nudges based on predicted cycle events. '
              'Select presets below or create your own with +.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(presets.length, (i) {
                final p = presets[i];
                final isSelected = _selected.contains(i);
                return FilterChip(
                  label: Text(p.title),
                  selected: isSelected,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _selected.add(i);
                      } else {
                        _selected.remove(i);
                      }
                    });
                  },
                );
              }),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  for (final i in _selected) {
                    final p = presets[i];
                    await widget.controller.add(
                      title: p.title,
                      message: p.message,
                      triggerType: p.triggerType,
                      daysBefore: p.daysBefore,
                    );
                  }
                },
                child: Text(
                  'Add ${_selected.length} reminder${_selected.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});
  final CycleReminder reminder;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CycleRemindersController>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(reminder),
      child: ListTile(
        onTap: () => _showReminderSheet(context, c, existing: reminder),
        leading: Switch(
          value: reminder.enabled,
          onChanged: (_) => c.toggleEnabled(reminder),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            color: reminder.enabled ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          _triggerLabel(reminder),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  String _triggerLabel(CycleReminder r) {
    final type = switch (r.triggerType) {
      'before_period' => 'period start',
      'period_start' => 'period start',
      'fertile_start' => 'fertile window',
      'ovulation' => 'ovulation',
      _ => 'event',
    };
    if (r.daysBefore == 0) return 'On $type';
    return '${r.daysBefore} day${r.daysBefore == 1 ? '' : 's'} before $type';
  }
}

void _showReminderSheet(BuildContext context, CycleRemindersController c,
    {CycleReminder? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _ReminderSheetContent(controller: c, existing: existing),
  );
}

class _ReminderSheetContent extends StatefulWidget {
  const _ReminderSheetContent({required this.controller, this.existing});
  final CycleRemindersController controller;
  final CycleReminder? existing;

  @override
  State<_ReminderSheetContent> createState() => _ReminderSheetContentState();
}

class _ReminderSheetContentState extends State<_ReminderSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _msgCtrl;
  late final TextEditingController _daysCtrl;
  late String _triggerType;

  bool get _isEdit => widget.existing != null;

  static const _triggerOptions = {
    'before_period': 'Before period',
    'period_start': 'Period start',
    'fertile_start': 'Fertile window start',
    'ovulation': 'Ovulation',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _msgCtrl = TextEditingController(text: e?.message ?? '');
    _daysCtrl = TextEditingController(text: (e?.daysBefore ?? 2).toString());
    _triggerType = e?.triggerType ?? 'before_period';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(_isEdit ? 'Edit reminder' : 'New reminder',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notification message'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _triggerType,
              decoration: const InputDecoration(
                labelText: 'Trigger event',
                border: OutlineInputBorder(),
              ),
              items: _triggerOptions.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _triggerType = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _daysCtrl,
              decoration: const InputDecoration(
                labelText: 'Days before event',
                helperText: '0 = on the day itself',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(_daysCtrl.text.trim()) ?? 2;
                if (_isEdit) {
                  widget.controller.updateReminder(
                    widget.existing!,
                    title: _titleCtrl.text,
                    message: _msgCtrl.text,
                    triggerType: _triggerType,
                    daysBefore: days,
                    enabled: widget.existing!.enabled,
                  );
                } else {
                  widget.controller.add(
                    title: _titleCtrl.text,
                    message: _msgCtrl.text,
                    triggerType: _triggerType,
                    daysBefore: days,
                  );
                }
                Navigator.pop(context);
              },
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
