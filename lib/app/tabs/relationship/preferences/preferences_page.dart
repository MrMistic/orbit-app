import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/preferences_controller.dart';
import '../../../../database/models.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  static const _suggestedCategories = [
    'Sizes',
    'Food',
    'Favorites',
    'Dislikes',
    'Allergies',
    'Wishlist',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PreferencesController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences journal')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEntrySheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final grouped = c.grouped;
        if (grouped.isEmpty) {
          return const Center(
            child: Text('No preferences saved yet. Tap + to add one.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final entry in grouped.entries) ...[
              _CategoryHeader(category: entry.key),
              for (final pref in entry.value)
                _PrefTile(entry: pref),
            ],
          ],
        );
      }),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        category,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.entry});
  final PreferenceEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PreferencesController>();
    final theme = Theme.of(context);

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
        onTap: () => _showEntrySheet(context, c, existing: entry),
        title: Text(entry.label),
        trailing: Text(
          entry.value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

void _showEntrySheet(BuildContext context, PreferencesController c,
    {PreferenceEntry? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EntrySheetContent(controller: c, existing: existing),
  );
}

class _EntrySheetContent extends StatefulWidget {
  const _EntrySheetContent({required this.controller, this.existing});
  final PreferencesController controller;
  final PreferenceEntry? existing;

  @override
  State<_EntrySheetContent> createState() => _EntrySheetContentState();
}

class _EntrySheetContentState extends State<_EntrySheetContent> {
  late final TextEditingController _catCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _valueCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _catCtrl = TextEditingController(text: e?.category ?? '');
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _valueCtrl = TextEditingController(text: e?.value ?? '');
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _labelCtrl.dispose();
    _valueCtrl.dispose();
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
            Text(_isEdit ? 'Edit preference' : 'New preference',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _catCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Sizes, Food, Favorites',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PreferencesPage._suggestedCategories
                  .map((cat) => ActionChip(
                        label: Text(cat),
                        onPressed: () => _catCtrl.text = cat,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Shirt size, Favorite color',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueCtrl,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g. Medium, Blue',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_isEdit) {
                  widget.controller.updateEntry(
                    widget.existing!,
                    category: _catCtrl.text,
                    label: _labelCtrl.text,
                    value: _valueCtrl.text,
                  );
                } else {
                  widget.controller.add(
                    category: _catCtrl.text,
                    label: _labelCtrl.text,
                    value: _valueCtrl.text,
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
