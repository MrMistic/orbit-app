import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

class TabController extends GetxController {
  final _box = ObjectBox.instance.tabEntryBox;
  final tabs = <TabEntry>[].obs;
  final showSettled = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    tabs.assignAll(all);
  }

  /// Active tabs (non-zero balance).
  List<TabEntry> get active => tabs.where((t) => t.balance.abs() > 0.005).toList();

  /// Settled tabs (zero balance) — hidden by default.
  List<TabEntry> get settled => tabs.where((t) => t.balance.abs() <= 0.005).toList();

  void addFriend(String name) {
    if (name.trim().isEmpty) return;
    _box.put(TabEntry(friendName: name.trim()));
    _load();
  }

  void addAmount(TabEntry entry, double amount) {
    entry.balance += amount;
    entry.updatedAt = DateTime.now();
    _box.put(entry);
    _load();
  }

  void settle(TabEntry entry) {
    entry.balance = 0;
    entry.updatedAt = DateTime.now();
    _box.put(entry);
    _load();
  }

  void remove(TabEntry entry) {
    _box.remove(entry.id);
    _load();
  }
}

class TabTrackerPage extends StatelessWidget {
  const TabTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(TabController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tab tracker'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(c.showSettled.value ? Icons.visibility : Icons.visibility_off),
            tooltip: c.showSettled.value ? 'Hide settled' : 'Show settled',
            onPressed: () => c.showSettled.value = !c.showSettled.value,
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFriendDialog(context, c),
        child: const Icon(Icons.person_add),
      ),
      body: Obx(() {
        final active = c.active;
        final settledList = c.settled;
        if (active.isEmpty && settledList.isEmpty) {
          return const Center(child: Text('No tabs. Tap + to add a friend.'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            ...active.map((t) => _TabTile(entry: t, controller: c)),
            if (c.showSettled.value && settledList.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Settled', style: Theme.of(context).textTheme.titleSmall),
              ),
              ...settledList.map((t) => _TabTile(entry: t, controller: c)),
            ],
          ],
        );
      }),
    );
  }

  void _addFriendDialog(BuildContext context, TabController c) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add friend'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { c.addFriend(ctrl.text); Navigator.pop(ctx); },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TabTile extends StatelessWidget {
  const _TabTile({required this.entry, required this.controller});
  final TabEntry entry;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwed = entry.balance > 0;
    final owes = entry.balance < 0;
    final color = isOwed ? Colors.green : owes ? theme.colorScheme.error : null;
    final label = entry.balance.abs() < 0.005
        ? 'Settled'
        : isOwed
            ? 'owes you \$${entry.balance.toStringAsFixed(2)}'
            : 'you owe \$${entry.balance.abs().toStringAsFixed(2)}';

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(entry),
      child: ListTile(
        title: Text(entry.friendName),
        subtitle: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'You owe them',
              onPressed: () => _addAmount(context, controller, entry, negative: true),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'They owe you',
              onPressed: () => _addAmount(context, controller, entry, negative: false),
            ),
            if (entry.balance.abs() > 0.005)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark settled',
                onPressed: () => controller.settle(entry),
              ),
          ],
        ),
      ),
    );
  }

  void _addAmount(BuildContext context, TabController c, TabEntry entry, {required bool negative}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(negative ? 'You owe ${entry.friendName}' : '${entry.friendName} owes you'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount != null && amount > 0) {
                c.addAmount(entry, negative ? -amount : amount);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
