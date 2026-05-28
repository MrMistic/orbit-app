import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class MaintenanceController extends GetxController {
  final _box = ObjectBox.instance.maintenanceBox;

  final items = <MaintenanceItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    // Sort: overdue first, then soonest due
    all.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      final aDue = a.daysUntilDue ?? 99999;
      final bDue = b.daysUntilDue ?? 99999;
      return aDue.compareTo(bDue);
    });
    items.assignAll(all);
  }

  void add({
    required String title,
    String? category,
    String? notes,
    int? intervalDays,
  }) {
    final now = DateTime.now();
    DateTime? nextDue;
    if (intervalDays != null) {
      nextDue = now.add(Duration(days: intervalDays));
    }
    _box.put(MaintenanceItem(
      title: title,
      category: category,
      notes: notes,
      intervalDays: intervalDays,
      nextDueAt: nextDue,
    ));
    _load();
  }

  void updateItem(MaintenanceItem item) {
    _box.put(item);
    _load();
  }

  void markDone(MaintenanceItem item) {
    item.lastDoneAt = DateTime.now();
    if (item.intervalDays != null) {
      item.nextDueAt =
          DateTime.now().add(Duration(days: item.intervalDays!));
    } else {
      item.nextDueAt = null;
    }
    _box.put(item);
    _load();
    items.refresh();
  }

  void remove(MaintenanceItem item) {
    _box.remove(item.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MaintenanceController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMaintenanceSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.items;
        if (list.isEmpty) {
          return const Center(
              child: Text('No items yet. Tap + to add one.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _MaintenanceTile(item: list[i], controller: c),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({required this.item, required this.controller});
  final MaintenanceItem item;
  final MaintenanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = item.isOverdue;
    final daysUntil = item.daysUntilDue;
    final dueSoon = daysUntil != null && daysUntil <= 7 && !overdue;

    Color? tileColor;
    if (overdue) {
      tileColor = theme.colorScheme.errorContainer.withOpacity(0.3);
    } else if (dueSoon) {
      tileColor = Colors.orange.withOpacity(0.1);
    }

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
      child: Container(
        color: tileColor,
        child: ListTile(
          onTap: () =>
              _showMaintenanceSheet(context, controller, existing: item),
          title: Row(
            children: [
              Expanded(child: Text(item.title)),
              if (overdue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Overdue',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            [
              if (item.category != null && item.category!.isNotEmpty)
                item.category!,
              if (item.nextDueAt != null)
                overdue
                    ? 'Was due ${DateFormat.yMMMd().format(item.nextDueAt!)}'
                    : 'Due ${DateFormat.yMMMd().format(item.nextDueAt!)}',
              if (item.intervalDays != null)
                'Every ${item.intervalDays} days',
            ].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Mark done',
            onPressed: () => controller.markDone(item),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showMaintenanceSheet(BuildContext context, MaintenanceController c,
    {MaintenanceItem? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _MaintenanceSheetContent(controller: c, existing: existing),
  );
}

class _MaintenanceSheetContent extends StatefulWidget {
  const _MaintenanceSheetContent({required this.controller, this.existing});
  final MaintenanceController controller;
  final MaintenanceItem? existing;

  @override
  State<_MaintenanceSheetContent> createState() =>
      _MaintenanceSheetContentState();
}

class _MaintenanceSheetContentState
    extends State<_MaintenanceSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _intervalCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existing?.title ?? '');
    _catCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _notesCtrl =
        TextEditingController(text: widget.existing?.notes ?? '');
    _intervalCtrl = TextEditingController(
        text: widget.existing?.intervalDays?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _catCtrl.dispose();
    _notesCtrl.dispose();
    _intervalCtrl.dispose();
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
            Text(_isEdit ? 'Edit item' : 'New maintenance item',
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
              controller: _catCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Car, Home, Appliance',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _intervalCtrl,
              decoration: const InputDecoration(
                labelText: 'Interval (days)',
                hintText: 'e.g. 90',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
    final interval = int.tryParse(_intervalCtrl.text.trim());

    if (_isEdit) {
      final item = widget.existing!;
      item.title = title;
      item.category =
          _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null;
      item.notes =
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      item.intervalDays = interval;
      if (interval != null && item.lastDoneAt != null) {
        item.nextDueAt =
            item.lastDoneAt!.add(Duration(days: interval));
      }
      widget.controller.updateItem(item);
    } else {
      widget.controller.add(
        title: title,
        category:
            _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        intervalDays: interval,
      );
    }
    Navigator.pop(context);
  }
}
