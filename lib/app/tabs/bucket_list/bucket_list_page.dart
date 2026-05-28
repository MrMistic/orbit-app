import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class BucketListController extends GetxController {
  final _box = ObjectBox.instance.bucketListBox;

  final items = <BucketListItem>[].obs;
  final categoryFilter = RxnString();

  static const suggestedCategories = [
    'Travel',
    'Career',
    'Experience',
    'Creative',
    'Personal',
    'Adventure',
  ];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    items.assignAll(_box.getAll());
  }

  List<String> get allCategories {
    final cats = items
        .where((i) => i.category != null && i.category!.isNotEmpty)
        .map((i) => i.category!)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<BucketListItem> get undone {
    var list = items.where((i) => !i.done).toList();
    if (categoryFilter.value != null) {
      list = list.where((i) => i.category == categoryFilter.value).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<BucketListItem> get done {
    var list = items.where((i) => i.done).toList();
    if (categoryFilter.value != null) {
      list = list.where((i) => i.category == categoryFilter.value).toList();
    }
    list.sort((a, b) =>
        (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    return list;
  }

  void add({required String title, String? notes, String? category}) {
    _box.put(BucketListItem(
      title: title,
      notes: notes,
      category: category,
    ));
    _load();
  }

  void updateItem(BucketListItem item) {
    _box.put(item);
    _load();
  }

  void toggleDone(BucketListItem item) {
    item.done = !item.done;
    item.completedAt = item.done ? DateTime.now() : null;
    _box.put(item);
    _load();
  }

  void remove(BucketListItem item) {
    _box.remove(item.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class BucketListPage extends StatelessWidget {
  const BucketListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(BucketListController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Bucket list')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBucketSheet(context, c),
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
              final undoneList = c.undone;
              final doneList = c.done;
              if (undoneList.isEmpty && doneList.isEmpty) {
                return const Center(
                    child: Text('Nothing here yet. Tap + to add.'));
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (undoneList.isNotEmpty) ...[
                    for (final item in undoneList)
                      _BucketTile(item: item, controller: c),
                  ],
                  if (doneList.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Completed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final item in doneList)
                      _BucketTile(item: item, controller: c),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _BucketTile extends StatelessWidget {
  const _BucketTile({required this.item, required this.controller});
  final BucketListItem item;
  final BucketListController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(item),
      child: ListTile(
        onTap: () => _showBucketSheet(context, controller, existing: item),
        leading: IconButton(
          icon: Icon(
            item.done ? Icons.check_circle : Icons.circle_outlined,
            color: item.done ? theme.colorScheme.primary : null,
          ),
          onPressed: () => controller.toggleDone(item),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (item.category != null && item.category!.isNotEmpty) {
      parts.add(item.category!);
    }
    if (item.notes != null && item.notes!.isNotEmpty) {
      parts.add(item.notes!);
    }
    if (item.done && item.completedAt != null) {
      parts.add('Done ${DateFormat.yMMMd().format(item.completedAt!)}');
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

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showBucketSheet(BuildContext context, BucketListController c,
    {BucketListItem? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _BucketSheetContent(controller: c, existing: existing),
  );
}

class _BucketSheetContent extends StatefulWidget {
  const _BucketSheetContent({required this.controller, this.existing});
  final BucketListController controller;
  final BucketListItem? existing;

  @override
  State<_BucketSheetContent> createState() => _BucketSheetContentState();
}

class _BucketSheetContentState extends State<_BucketSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _catCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl =
        TextEditingController(text: widget.existing?.notes ?? '');
    _catCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
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
            Text(_isEdit ? 'Edit item' : 'New bucket list item',
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
                hintText: 'e.g. Travel, Career, Experience',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: BucketListController.suggestedCategories
                  .map((cat) => ActionChip(
                        label: Text(cat),
                        onPressed: () => _catCtrl.text = cat,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (_isEdit) {
      final item = widget.existing!;
      item.title = title;
      item.notes =
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      item.category =
          _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null;
      widget.controller.updateItem(item);
    } else {
      widget.controller.add(
        title: title,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        category:
            _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null,
      );
    }
    Navigator.pop(context);
  }
}
