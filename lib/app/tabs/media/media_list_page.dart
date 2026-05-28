import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class MediaListController extends GetxController {
  final _box = ObjectBox.instance.mediaBox;

  final items = <MediaItem>[].obs;
  final statusFilter = 'want'.obs;
  final typeFilter = RxnString();

  static const mediaTypes = [
    'book',
    'movie',
    'show',
    'podcast',
    'game',
    'article',
  ];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    items.assignAll(_box.getAll());
  }

  List<MediaItem> get filtered {
    var list = items.where((i) => i.status == statusFilter.value).toList();
    if (typeFilter.value != null) {
      list = list.where((i) => i.mediaType == typeFilter.value).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void add({
    required String title,
    String? author,
    required String mediaType,
    required String status,
  }) {
    final item = MediaItem(
      title: title,
      author: author?.isNotEmpty == true ? author : null,
      mediaType: mediaType,
      status: status,
    );
    if (status == 'in_progress') item.startedAt = DateTime.now();
    _box.put(item);
    _load();
  }

  void updateItem(MediaItem item) {
    _box.put(item);
    _load();
  }

  void remove(MediaItem item) {
    _box.remove(item.id);
    _load();
  }

  void markFinished(MediaItem item, int rating) {
    item.status = 'finished';
    item.rating = rating;
    item.finishedAt = DateTime.now();
    _box.put(item);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MediaListPage extends StatelessWidget {
  const MediaListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MediaListController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Media list')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMediaSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Status tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Obx(() => Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Want'),
                      selected: c.statusFilter.value == 'want',
                      onSelected: (_) => c.statusFilter.value = 'want',
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('In progress'),
                      selected: c.statusFilter.value == 'in_progress',
                      onSelected: (_) => c.statusFilter.value = 'in_progress',
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Finished'),
                      selected: c.statusFilter.value == 'finished',
                      onSelected: (_) => c.statusFilter.value = 'finished',
                    ),
                  ],
                )),
          ),
          // Type filter
          Obx(() {
            return SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: c.typeFilter.value == null,
                      onSelected: (_) => c.typeFilter.value = null,
                    ),
                  ),
                  for (final t in MediaListController.mediaTypes)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        selected: c.typeFilter.value == t,
                        onSelected: (on) =>
                            c.typeFilter.value = on ? t : null,
                      ),
                    ),
                ],
              ),
            );
          }),
          // List
          Expanded(
            child: Obx(() {
              final list = c.filtered;
              if (list.isEmpty) {
                return const Center(child: Text('Nothing here yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _MediaTile(item: list[i], controller: c),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item, required this.controller});
  final MediaItem item;
  final MediaListController controller;

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
        onTap: () => _showMediaSheet(context, controller, existing: item),
        title: Text(item.title),
        subtitle: Text(
          [
            if (item.author != null && item.author!.isNotEmpty) item.author!,
            item.mediaType[0].toUpperCase() + item.mediaType.substring(1),
            if (item.rating != null) '${'⭐' * item.rating!}',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: item.status == 'in_progress'
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark finished',
                onPressed: () => _showRatingDialog(context, controller, item),
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showMediaSheet(BuildContext context, MediaListController c,
    {MediaItem? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _MediaSheetContent(controller: c, existing: existing),
  );
}

class _MediaSheetContent extends StatefulWidget {
  const _MediaSheetContent({required this.controller, this.existing});
  final MediaListController controller;
  final MediaItem? existing;

  @override
  State<_MediaSheetContent> createState() => _MediaSheetContentState();
}

class _MediaSheetContentState extends State<_MediaSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  late String _status;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _authorCtrl = TextEditingController(text: widget.existing?.author ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _type = widget.existing?.mediaType ?? 'book';
    _status = widget.existing?.status ?? 'want';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
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
            Text(_isEdit ? 'Edit item' : 'Add media',
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
              controller: _authorCtrl,
              decoration:
                  const InputDecoration(labelText: 'Author (optional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: MediaListController.mediaTypes
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child:
                          Text(t[0].toUpperCase() + t.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'want', child: Text('Want')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(
                    value: 'finished', child: Text('Finished')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
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
      item.author =
          _authorCtrl.text.trim().isNotEmpty ? _authorCtrl.text.trim() : null;
      item.mediaType = _type;
      item.notes =
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      if (item.status != _status) {
        item.status = _status;
        if (_status == 'in_progress') item.startedAt ??= DateTime.now();
        if (_status == 'finished') item.finishedAt ??= DateTime.now();
      }
      widget.controller.updateItem(item);
    } else {
      widget.controller.add(
        title: title,
        author: _authorCtrl.text.trim(),
        mediaType: _type,
        status: _status,
      );
    }
    Navigator.pop(context);
  }
}

// ---------------------------------------------------------------------------
// Rating dialog
// ---------------------------------------------------------------------------

void _showRatingDialog(
    BuildContext context, MediaListController c, MediaItem item) {
  int rating = 3;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Rate it'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            return IconButton(
              icon: Icon(
                i < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () => setState(() => rating = i + 1),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              c.markFinished(item, rating);
              Navigator.pop(ctx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}
