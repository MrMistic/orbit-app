import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/shopping_controller.dart';
import '../../../database/models.dart';

class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ShoppingController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'clear_checked':
                  await c.clearChecked();
                  break;
                case 'clear_all':
                  final confirm = await _confirm(
                      context, 'Clear all items?', 'This cannot be undone.');
                  if (confirm) await c.clearAll();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear_checked',
                child: Text('Clear checked'),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear all'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addManual(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.items;
        if (list.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _ShoppingTile(item: list[i]),
        );
      }),
    );
  }

  Future<void> _addManual(BuildContext context, ShoppingController c) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add item', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                c.addManual(
                  nameCtrl.text,
                  quantity: double.tryParse(qtyCtrl.text.trim()),
                  unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Your list is empty', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add items manually or open a recipe and choose "Add to shopping".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({required this.item});
  final ShoppingItem item;

  String _qtyDisplay() {
    final parts = <String>[];
    if (item.quantity != null) {
      final q = item.quantity!;
      parts.add(q == q.truncateToDouble() ? q.toInt().toString() : q.toString());
    }
    if (item.unit != null && item.unit!.isNotEmpty) parts.add(item.unit!);
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShoppingController>();
    final theme = Theme.of(context);
    final qty = _qtyDisplay();

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(item),
      child: ListTile(
        leading: Checkbox(
          value: item.checked,
          onChanged: (_) => c.toggleChecked(item),
        ),
        title: Text(
          qty.isEmpty ? item.name : '$qty ${item.name}',
          style: TextStyle(
            decoration: item.checked ? TextDecoration.lineThrough : null,
            color: item.checked ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: item.sourceRecipe != null
            ? Text(item.sourceRecipe!, style: theme.textTheme.bodySmall)
            : null,
      ),
    );
  }
}
