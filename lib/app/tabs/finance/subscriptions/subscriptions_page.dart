import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SubscriptionsController extends GetxController {
  final _box = ObjectBox.instance.subscriptionBox;
  final items = <Subscription>[].obs;
  final showInactive = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) {
      // Active first.
      if (a.active != b.active) return a.active ? -1 : 1;
      // Then by next renewal (soonest first, nulls last).
      final aDays = a.daysUntilRenewal ?? 99999;
      final bDays = b.daysUntilRenewal ?? 99999;
      return aDays.compareTo(bDays);
    });
    items.assignAll(all);
  }

  /// Filtered view based on showInactive toggle.
  List<Subscription> get filtered {
    if (showInactive.value) return items;
    return items.where((s) => s.active).toList();
  }

  /// Total monthly burn from active subscriptions.
  double get monthlyTotal {
    return items
        .where((s) => s.active)
        .fold<double>(0, (sum, s) => sum + s.monthlyCost);
  }

  /// Total yearly burn.
  double get yearlyTotal => monthlyTotal * 12;

  void add({
    required String name,
    required double amount,
    required String billingCycle,
    String kind = 'subscription',
    String? category,
    String? notes,
    DateTime? nextRenewal,
  }) {
    _box.put(Subscription(
      name: name.trim(),
      amount: amount,
      billingCycle: billingCycle,
      kind: kind,
      category: category?.trim().isEmpty ?? true ? null : category!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      nextRenewal: nextRenewal,
    ));
    _load();
  }

  void updateSub(Subscription sub) {
    _box.put(sub);
    _load();
    items.refresh();
  }

  void toggleActive(Subscription sub) {
    sub.active = !sub.active;
    _box.put(sub);
    _load();
    items.refresh();
  }

  void remove(Subscription sub) {
    _box.remove(sub.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SubscriptionsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & subscriptions'),
        actions: [
          Obx(() {
            final on = c.showInactive.value;
            return IconButton(
              tooltip: on ? 'Hide inactive' : 'Show inactive',
              icon: Icon(on ? Icons.visibility : Icons.visibility_off),
              onPressed: () => c.showInactive.value = !on,
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.filtered;
        return Column(
          children: [
            if (c.items.where((s) => s.active).isNotEmpty)
              _TotalsCard(controller: c),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('No subscriptions yet. Tap + to add.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _SubTile(sub: list[i], controller: c),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.controller});
  final SubscriptionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text(
                  fmt.format(controller.monthlyTotal),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('per month', style: theme.textTheme.bodySmall),
              ],
            ),
            Column(
              children: [
                Text(
                  fmt.format(controller.yearlyTotal),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('per year', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({required this.sub, required this.controller});
  final Subscription sub;
  final SubscriptionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final days = sub.daysUntilRenewal;
    final dueSoon = days != null && days >= 0 && days <= 7 && sub.active;
    final overdue = days != null && days < 0 && sub.active;

    return Dismissible(
      key: ValueKey(sub.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(sub),
      child: ListTile(
        onTap: () => _showSubSheet(context, controller, existing: sub),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sub.name,
                style: TextStyle(
                  color: sub.active ? null : theme.colorScheme.onSurfaceVariant,
                  decoration: sub.active ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (overdue)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Renews now',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                  ),
                ),
              )
            else if (dueSoon)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${days}d',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            '${fmt.format(sub.amount)}/${_cycleLabel(sub.billingCycle)}',
            if (sub.category != null) sub.category!,
            if (sub.nextRenewal != null && sub.active)
              'Renews ${DateFormat.MMMd().format(sub.nextRenewal!)}',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Switch(
          value: sub.active,
          onChanged: (_) => controller.toggleActive(sub),
        ),
      ),
    );
  }

  String _cycleLabel(String cycle) {
    return switch (cycle) {
      'weekly' => 'wk',
      'monthly' => 'mo',
      'quarterly' => 'qtr',
      'yearly' => 'yr',
      _ => cycle,
    };
  }
}

void _showSubSheet(BuildContext context, SubscriptionsController c,
    {Subscription? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SubSheetContent(controller: c, existing: existing),
  );
}

class _SubSheetContent extends StatefulWidget {
  const _SubSheetContent({required this.controller, this.existing});
  final SubscriptionsController controller;
  final Subscription? existing;

  @override
  State<_SubSheetContent> createState() => _SubSheetContentState();
}

class _SubSheetContentState extends State<_SubSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _notesCtrl;
  late String _cycle;
  late String _kind;
  DateTime? _nextRenewal;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _amountCtrl =
        TextEditingController(text: widget.existing?.amount.toString() ?? '');
    _categoryCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _cycle = widget.existing?.billingCycle ?? 'monthly';
    _kind = widget.existing?.kind ?? 'subscription';
    _nextRenewal = widget.existing?.nextRenewal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
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
            Text(_isEdit ? 'Edit subscription' : 'New subscription',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'subscription', label: Text('Subscription')),
                ButtonSegment(value: 'bill', label: Text('Bill')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Netflix, Spotify',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _cycle,
                    decoration:
                        const InputDecoration(labelText: 'Billing cycle'),
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(
                          value: 'quarterly', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _cycle = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Entertainment, Software',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_nextRenewal != null
                  ? 'Next renewal: ${fmt.format(_nextRenewal!)}'
                  : 'Set next renewal date'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _nextRenewal ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 365)),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _nextRenewal = picked);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
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
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) return;

    if (_isEdit) {
      final sub = widget.existing!;
      sub.name = name;
      sub.amount = amount;
      sub.billingCycle = _cycle;
      sub.kind = _kind;
      sub.category =
          _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
      sub.notes =
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      sub.nextRenewal = _nextRenewal;
      widget.controller.updateSub(sub);
    } else {
      widget.controller.add(
        name: name,
        amount: amount,
        billingCycle: _cycle,
        kind: _kind,
        category: _categoryCtrl.text,
        notes: _notesCtrl.text,
        nextRenewal: _nextRenewal,
      );
    }
    Navigator.pop(context);
  }
}
