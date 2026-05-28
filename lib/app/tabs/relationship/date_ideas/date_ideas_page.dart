import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/date_ideas_controller.dart';
import '../../../../database/models.dart';

class DateIdeasPage extends StatelessWidget {
  const DateIdeasPage({super.key});

  static const _suggestedCategories = [
    'Restaurant',
    'Activity',
    'Trip',
    'At-home',
    'Outdoors',
    'Event',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DateIdeasController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Date ideas'),
        actions: [
          Obx(() {
            final on = c.showDone.value;
            return IconButton(
              tooltip: on ? 'Hide completed' : 'Show completed',
              icon: Icon(on ? Icons.visibility : Icons.visibility_off),
              onPressed: () => c.showDone.value = !c.showDone.value,
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIdeaSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Category filter chips
          Obx(() {
            final cats = c.allCategories;
            if (cats.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: c.categoryFilter.value == null,
                      onSelected: (_) => c.categoryFilter.value = null,
                    ),
                  ),
                  for (final cat in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat),
                        selected: c.categoryFilter.value == cat,
                        onSelected: (on) =>
                            c.categoryFilter.value = on ? cat : null,
                      ),
                    ),
                ],
              ),
            );
          }),
          // List
          Expanded(
            child: Obx(() {
              final list = c.ideas;
              if (list.isEmpty) {
                return const Center(
                  child: Text('No ideas yet. Tap + to add one.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (_, i) => _IdeaTile(idea: list[i]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

void _showIdeaSheet(BuildContext context, DateIdeasController c,
    {DateIdea? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _IdeaSheetContent(
      controller: c,
      existing: existing,
    ),
  );
}

class _IdeaSheetContent extends StatefulWidget {
  const _IdeaSheetContent({required this.controller, this.existing});
  final DateIdeasController controller;
  final DateIdea? existing;

  @override
  State<_IdeaSheetContent> createState() => _IdeaSheetContentState();
}

class _IdeaSheetContentState extends State<_IdeaSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _catCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _catCtrl = TextEditingController(text: widget.existing?.category ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _catCtrl.dispose();
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
            Text(_isEdit ? 'Edit idea' : 'New date idea',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _catCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Restaurant, Activity, Trip',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: DateIdeasPage._suggestedCategories
                  .map((cat) => ActionChip(
                        label: Text(cat),
                        onPressed: () => _catCtrl.text = cat,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_isEdit) {
                  widget.controller.updateIdea(
                    widget.existing!,
                    title: _titleCtrl.text,
                    notes: _notesCtrl.text,
                    category: _catCtrl.text,
                  );
                } else {
                  widget.controller.add(
                    _titleCtrl.text,
                    notes: _notesCtrl.text,
                    category: _catCtrl.text,
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

class _IdeaTile extends StatelessWidget {
  const _IdeaTile({required this.idea});
  final DateIdea idea;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DateIdeasController>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(idea.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(idea),
      child: ListTile(
        onTap: () => _showIdeaSheet(context, c, existing: idea),
        leading: IconButton(
          icon: Icon(
            idea.done ? Icons.check_circle : Icons.circle_outlined,
            color: idea.done ? theme.colorScheme.primary : null,
          ),
          onPressed: () => c.toggleDone(idea),
        ),
        title: Text(
          idea.title,
          style: TextStyle(
            decoration: idea.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (idea.category.isNotEmpty) parts.add(idea.category);
    if (idea.notes != null && idea.notes!.isNotEmpty) parts.add(idea.notes!);
    if (idea.done && idea.completedAt != null) {
      parts.add('Done ${DateFormat.yMMMd().format(idea.completedAt!)}');
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
