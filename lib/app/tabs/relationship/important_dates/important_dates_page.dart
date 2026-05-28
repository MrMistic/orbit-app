import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/important_dates_controller.dart';
import '../../../../database/models.dart';

class ImportantDatesPage extends StatelessWidget {
  const ImportantDatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ImportantDatesController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Important dates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDateSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.dates;
        if (list.isEmpty) {
          return const Center(
            child: Text('No dates yet. Tap + to add one.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _DateTile(entry: list[i]),
        );
      }),
    );
  }
}

void _showDateSheet(BuildContext context, ImportantDatesController c,
    {ImportantDate? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _DateSheetContent(controller: c, existing: existing),
  );
}

class _DateSheetContent extends StatefulWidget {
  const _DateSheetContent({required this.controller, this.existing});
  final ImportantDatesController controller;
  final ImportantDate? existing;

  @override
  State<_DateSheetContent> createState() => _DateSheetContentState();
}

class _DateSheetContentState extends State<_DateSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  late bool _recurring;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _recurring = e?.recurring ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
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
            Text(_isEdit ? 'Edit date' : 'New important date',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Our anniversary, Her birthday',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(DateFormat.yMMMd().format(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Repeats annually'),
              subtitle: Text(_recurring
                  ? 'Shows countdown to next occurrence each year'
                  : 'One-time milestone, shows time since'),
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_isEdit) {
                  widget.controller.updateDate(
                    widget.existing!,
                    title: _titleCtrl.text,
                    notes: _notesCtrl.text,
                    date: _date,
                    recurring: _recurring,
                  );
                } else {
                  widget.controller.add(
                    title: _titleCtrl.text,
                    notes: _notesCtrl.text,
                    date: _date,
                    recurring: _recurring,
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

class _DateTile extends StatelessWidget {
  const _DateTile({required this.entry});
  final ImportantDate entry;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ImportantDatesController>();
    final theme = Theme.of(context);
    final days = entry.daysUntil;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(entry),
      child: ListTile(
        onTap: () => _showDateSheet(context, c, existing: entry),
        leading: _CountdownBadge(days: days, recurring: entry.recurring),
        title: Text(entry.title),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    parts.add(DateFormat.yMMMd().format(entry.date));
    if (entry.recurring && entry.yearsSince > 0) {
      final y = entry.yearsSince;
      parts.add('${_ordinal(y)} year');
    }
    if (!entry.recurring) {
      final d = entry.daysSince;
      if (d > 365) {
        final years = d ~/ 365;
        parts.add('$years year${years == 1 ? '' : 's'} ago');
      } else {
        parts.add('$d day${d == 1 ? '' : 's'} ago');
      }
    }
    if (entry.notes != null && entry.notes!.isNotEmpty) {
      parts.add(entry.notes!);
    }
    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.days, required this.recurring});
  final int days;
  final bool recurring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    String label;

    if (days == 0) {
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
      label = 'Today';
    } else if (days <= 7) {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.onPrimaryContainer;
      label = '${days}d';
    } else if (days <= 30) {
      bg = theme.colorScheme.tertiaryContainer;
      fg = theme.colorScheme.onTertiaryContainer;
      label = '${days}d';
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
      label = '${days}d';
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: fg),
      ),
    );
  }
}
