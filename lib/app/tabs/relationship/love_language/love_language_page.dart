import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../controllers/love_language_controller.dart';
import '../../../../data/love_language_suggestions.dart';
import '../../../../database/models.dart';

class LoveLanguagePage extends StatelessWidget {
  const LoveLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(LoveLanguageController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Love languages'),
        actions: [
          IconButton(
            tooltip: 'Random suggestion',
            icon: const Icon(Icons.shuffle),
            onPressed: () => _showRandom(context, c),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.reminders;
        if (list.isEmpty) {
          return _SetupView(controller: c);
        }
        // Group by language.
        final grouped = <String, List<LoveLanguageReminder>>{};
        for (final r in list) {
          grouped.putIfAbsent(r.language, () => []).add(r);
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final entry in grouped.entries) ...[
              _LanguageHeader(language: entry.key),
              for (final r in entry.value) _ReminderTile(reminder: r),
            ],
          ],
        );
      }),
    );
  }

  void _showRandom(BuildContext context, LoveLanguageController c) {
    final suggestion = c.getRandomSuggestion();
    if (suggestion == null) {
      Get.snackbar('No reminders', 'Add some love language actions first.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Try this today'),
        content: Text(suggestion, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  const _LanguageHeader({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = loveLanguageLabels[language] ?? language;
    final emoji = loveLanguageIcons[language] ?? '❤️';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$emoji $label',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});
  final LoveLanguageReminder reminder;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<LoveLanguageController>();
    final theme = Theme.of(context);

    final freq = reminder.frequencyDays == 1
        ? 'Daily'
        : 'Every ${reminder.frequencyDays} days';

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
        onTap: () => _showEditSheet(context, c, reminder),
        leading: Switch(
          value: reminder.enabled,
          onChanged: (_) => c.toggleEnabled(reminder),
        ),
        title: Text(
          reminder.action,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: reminder.enabled ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(freq, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

/// Setup view: multi-select suggestions across all languages.
class _SetupView extends StatefulWidget {
  const _SetupView({required this.controller});
  final LoveLanguageController controller;

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final Set<String> _selected = {}; // "language:index" keys

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Choose reminders', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Select actions you want to be reminded about. '
          'You can customize frequency after adding.',
        ),
        const SizedBox(height: 16),
        for (final lang in loveLanguageSuggestions.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              '${loveLanguageIcons[lang.key] ?? ''} ${loveLanguageLabels[lang.key] ?? lang.key}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(lang.value.length, (i) {
              final key = '${lang.key}:$i';
              return FilterChip(
                label: Text(
                  lang.value[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _selected.contains(key),
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      _selected.add(key);
                    } else {
                      _selected.remove(key);
                    }
                  });
                },
              );
            }),
          ),
        ],
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _addSelected,
            child: Text(
              'Add ${_selected.length} reminder${_selected.length == 1 ? '' : 's'}',
            ),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }

  Future<void> _addSelected() async {
    final items = <LoveLanguageReminder>[];
    for (final key in _selected) {
      final parts = key.split(':');
      final lang = parts[0];
      final idx = int.parse(parts[1]);
      final suggestions = loveLanguageSuggestions[lang];
      if (suggestions == null || idx >= suggestions.length) continue;
      items.add(LoveLanguageReminder(
        language: lang,
        action: suggestions[idx],
        frequencyDays: 3,
      ));
    }
    await widget.controller.addBatch(items);
  }
}

void _showAddSheet(BuildContext context, LoveLanguageController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AddSheetContent(controller: c),
  );
}

void _showEditSheet(
    BuildContext context, LoveLanguageController c, LoveLanguageReminder r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EditSheetContent(controller: c, reminder: r),
  );
}

class _AddSheetContent extends StatefulWidget {
  const _AddSheetContent({required this.controller});
  final LoveLanguageController controller;

  @override
  State<_AddSheetContent> createState() => _AddSheetContentState();
}

class _AddSheetContentState extends State<_AddSheetContent> {
  final _actionCtrl = TextEditingController();
  final _freqCtrl = TextEditingController(text: '3');
  String _language = 'words';

  @override
  void dispose() {
    _actionCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New reminder', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(
                labelText: 'Love language',
                border: OutlineInputBorder(),
              ),
              items: loveLanguageLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _language = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actionCtrl,
              decoration: const InputDecoration(
                labelText: 'Action / suggestion',
                hintText: 'What should the reminder say?',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _freqCtrl,
              decoration: const InputDecoration(
                labelText: 'Frequency (days)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.controller.add(
                  language: _language,
                  action: _actionCtrl.text,
                  frequencyDays: int.tryParse(_freqCtrl.text) ?? 3,
                );
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSheetContent extends StatefulWidget {
  const _EditSheetContent({required this.controller, required this.reminder});
  final LoveLanguageController controller;
  final LoveLanguageReminder reminder;

  @override
  State<_EditSheetContent> createState() => _EditSheetContentState();
}

class _EditSheetContentState extends State<_EditSheetContent> {
  late final TextEditingController _actionCtrl;
  late final TextEditingController _freqCtrl;

  @override
  void initState() {
    super.initState();
    _actionCtrl = TextEditingController(text: widget.reminder.action);
    _freqCtrl =
        TextEditingController(text: widget.reminder.frequencyDays.toString());
  }

  @override
  void dispose() {
    _actionCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit reminder', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _actionCtrl,
              decoration: const InputDecoration(labelText: 'Action'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _freqCtrl,
              decoration: const InputDecoration(
                labelText: 'Frequency (days)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.controller.updateReminder(
                  widget.reminder,
                  action: _actionCtrl.text,
                  frequencyDays: int.tryParse(_freqCtrl.text) ?? 3,
                  enabled: widget.reminder.enabled,
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
}
