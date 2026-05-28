import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SavingsGoalsController extends GetxController {
  final _box = ObjectBox.instance.savingsGoalBox;
  final items = <SavingsGoal>[].obs;

  /// "all", "savings", "wishlist".
  final typeFilter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) {
      // Achieved go to bottom.
      if (a.achieved != b.achieved) return a.achieved ? 1 : -1;
      // Then by target date (soonest first, nulls last).
      final aDays = a.daysUntilTarget ?? 99999;
      final bDays = b.daysUntilTarget ?? 99999;
      if (aDays != bDays) return aDays.compareTo(bDays);
      return b.createdAt.compareTo(a.createdAt);
    });
    items.assignAll(all);
  }

  List<SavingsGoal> get filtered {
    if (typeFilter.value == 'all') return items;
    return items.where((g) => g.type == typeFilter.value).toList();
  }

  void add({
    required String name,
    String? notes,
    required double targetAmount,
    double savedAmount = 0,
    String? linkUrl,
    required String type,
    String? category,
    DateTime? targetDate,
  }) {
    _box.put(SavingsGoal(
      name: name.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      linkUrl: linkUrl?.trim().isEmpty ?? true ? null : linkUrl!.trim(),
      type: type,
      category: category?.trim().isEmpty ?? true ? null : category!.trim(),
      targetDate: targetDate,
    ));
    _load();
  }

  void updateGoal(SavingsGoal goal) {
    _box.put(goal);
    _load();
    items.refresh();
  }

  void addSavings(SavingsGoal goal, double amount) {
    goal.savedAmount += amount;
    if (goal.savedAmount >= goal.targetAmount && !goal.achieved) {
      goal.achieved = true;
      goal.achievedAt = DateTime.now();
    }
    _box.put(goal);
    _load();
    items.refresh();
  }

  void toggleAchieved(SavingsGoal goal) {
    goal.achieved = !goal.achieved;
    goal.achievedAt = goal.achieved ? DateTime.now() : null;
    _box.put(goal);
    _load();
    items.refresh();
  }

  void remove(SavingsGoal goal) {
    _box.remove(goal.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class SavingsGoalsPage extends StatelessWidget {
  const SavingsGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SavingsGoalsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings & wishlist')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Obx(() => Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: c.typeFilter.value == 'all',
                      onSelected: (_) => c.typeFilter.value = 'all',
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Savings'),
                      selected: c.typeFilter.value == 'savings',
                      onSelected: (_) => c.typeFilter.value = 'savings',
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Wishlist'),
                      selected: c.typeFilter.value == 'wishlist',
                      onSelected: (_) => c.typeFilter.value = 'wishlist',
                    ),
                  ],
                )),
          ),
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
                    _GoalCard(goal: list[i], controller: c),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.controller});
  final SavingsGoal goal;
  final SavingsGoalsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat.MMMd();

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(goal),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => _showGoalSheet(context, controller, existing: goal),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      goal.type == 'wishlist'
                          ? Icons.favorite_outline
                          : Icons.savings_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(goal.name,
                          style: theme.textTheme.titleMedium),
                    ),
                    if (goal.achieved)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${fmt.format(goal.savedAmount)} / ${fmt.format(goal.targetAmount)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: goal.progress,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(goal.progress * 100).round()}% saved'
                  '${goal.targetDate != null ? ' • ${dateFmt.format(goal.targetDate!)}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(goal.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!goal.achieved)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add savings'),
                        onPressed: () => _showAddSavingsDialog(
                            context, controller, goal),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs and sheets
// ---------------------------------------------------------------------------

void _showAddSavingsDialog(
    BuildContext context, SavingsGoalsController c, SavingsGoal goal) {
  final ctrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Add to ${goal.name}'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Amount',
          prefixText: '\$ ',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(ctrl.text.trim());
            if (amount != null && amount > 0) {
              c.addSavings(goal, amount);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

void _showGoalSheet(BuildContext context, SavingsGoalsController c,
    {SavingsGoal? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _GoalSheetContent(controller: c, existing: existing),
  );
}

class _GoalSheetContent extends StatefulWidget {
  const _GoalSheetContent({required this.controller, this.existing});
  final SavingsGoalsController controller;
  final SavingsGoal? existing;

  @override
  State<_GoalSheetContent> createState() => _GoalSheetContentState();
}

class _GoalSheetContentState extends State<_GoalSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _savedCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _linkCtrl;
  late String _type;
  DateTime? _targetDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _targetCtrl = TextEditingController(
        text: widget.existing?.targetAmount.toString() ?? '');
    _savedCtrl = TextEditingController(
        text: widget.existing?.savedAmount.toString() ?? '0');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _categoryCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _linkCtrl = TextEditingController(text: widget.existing?.linkUrl ?? '');
    _type = widget.existing?.type ?? 'savings';
    _targetDate = widget.existing?.targetDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    _notesCtrl.dispose();
    _categoryCtrl.dispose();
    _linkCtrl.dispose();
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
            Text(_isEdit ? 'Edit goal' : 'New goal',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'savings', label: Text('Savings goal')),
                ButtonSegment(value: 'wishlist', label: Text('Wishlist')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: _type == 'wishlist'
                    ? 'e.g. New camera, MacBook Pro'
                    : 'e.g. Vacation fund, Emergency fund',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target',
                      prefixText: '\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _savedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Saved so far',
                      prefixText: '\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Travel, Tech',
              ),
            ),
            if (_type == 'wishlist') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product link (optional)',
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_targetDate != null
                  ? 'Target: ${fmt.format(_targetDate!)}'
                  : 'Set target date (optional)'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _targetDate ?? DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) setState(() => _targetDate = picked);
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
    final target = double.tryParse(_targetCtrl.text.trim());
    final saved = double.tryParse(_savedCtrl.text.trim()) ?? 0;
    if (name.isEmpty || target == null || target <= 0) return;

    if (_isEdit) {
      final goal = widget.existing!;
      goal.name = name;
      goal.targetAmount = target;
      goal.savedAmount = saved;
      goal.type = _type;
      goal.category = _categoryCtrl.text.trim().isEmpty
          ? null
          : _categoryCtrl.text.trim();
      goal.linkUrl =
          _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim();
      goal.notes =
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      goal.targetDate = _targetDate;
      widget.controller.updateGoal(goal);
    } else {
      widget.controller.add(
        name: name,
        targetAmount: target,
        savedAmount: saved,
        type: _type,
        category: _categoryCtrl.text,
        linkUrl: _linkCtrl.text,
        notes: _notesCtrl.text,
        targetDate: _targetDate,
      );
    }
    Navigator.pop(context);
  }
}
