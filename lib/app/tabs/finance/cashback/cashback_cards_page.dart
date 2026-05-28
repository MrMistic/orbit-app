import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class CashbackController extends GetxController {
  final _box = ObjectBox.instance.rewardsCardBox;
  final cards = <RewardsCard>[].obs;
  final categoryQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    cards.assignAll(all);
  }

  void add({
    required String name,
    String? notes,
    String categoriesRaw = '',
    String? activeRotatingCategory,
    double annualFee = 0,
    double? apr,
    bool isDefault = false,
  }) {
    if (isDefault) _clearOtherDefaults();
    _box.put(RewardsCard(
      name: name.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      categoriesRaw: categoriesRaw,
      activeRotatingCategory: activeRotatingCategory?.trim().isEmpty ?? true
          ? null
          : activeRotatingCategory!.trim(),
      annualFee: annualFee,
      apr: apr,
      isDefault: isDefault,
    ));
    _load();
  }

  void updateCard(RewardsCard card) {
    if (card.isDefault) _clearOtherDefaults(except: card.id);
    _box.put(card);
    _load();
    cards.refresh();
  }

  void _clearOtherDefaults({int? except}) {
    final defaults = _box.getAll().where((c) => c.isDefault).toList();
    for (final c in defaults) {
      if (except != null && c.id == except) continue;
      c.isDefault = false;
      _box.put(c);
    }
  }

  RewardsCard? get defaultCard {
    return cards.firstWhereOrNull((c) => c.isDefault);
  }

  void toggleActive(RewardsCard card) {
    card.active = !card.active;
    _box.put(card);
    _load();
    cards.refresh();
  }

  void remove(RewardsCard card) {
    _box.remove(card.id);
    _load();
  }

  /// Find the best card for a category. Returns the card with the highest
  /// matching cashback percent, or the highest "Everything else" percent.
  /// Match is case-insensitive substring search both ways.
  (RewardsCard, double, String)? bestCardFor(String category) {
    final query = category.trim().toLowerCase();
    if (query.isEmpty) return null;

    RewardsCard? best;
    double bestPct = -1;
    String bestMatched = '';

    for (final card in cards) {
      if (!card.active) continue;
      double cardBest = -1;
      String cardMatched = '';
      for (final (cat, pct) in card.categories) {
        final catLower = cat.toLowerCase();
        // Direct match (substring either direction).
        if (catLower.contains(query) || query.contains(catLower)) {
          if (pct > cardBest) {
            cardBest = pct;
            cardMatched = cat;
          }
        }
        // Active rotating category bonus.
        if (card.activeRotatingCategory != null &&
            (card.activeRotatingCategory!.toLowerCase().contains(query) ||
                query.contains(card.activeRotatingCategory!.toLowerCase())) &&
            catLower == card.activeRotatingCategory!.toLowerCase()) {
          if (pct > cardBest) {
            cardBest = pct;
            cardMatched = cat;
          }
        }
      }
      // Fall back to "Everything else" / default.
      if (cardBest < 0) {
        for (final (cat, pct) in card.categories) {
          final catLower = cat.toLowerCase();
          if (catLower.contains('else') ||
              catLower.contains('other') ||
              catLower.contains('all') ||
              catLower == 'default') {
            if (pct > cardBest) {
              cardBest = pct;
              cardMatched = cat;
            }
          }
        }
      }
      if (cardBest > bestPct) {
        bestPct = cardBest;
        best = card;
        bestMatched = cardMatched;
      }
    }
    if (best == null) return null;
    return (best, bestPct, bestMatched);
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CashbackCardsPage extends StatelessWidget {
  const CashbackCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CashbackController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Cashback cards')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCardSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        return Column(
          children: [
            _BestCardLookup(controller: c),
            Expanded(
              child: c.cards.isEmpty
                  ? const Center(
                      child:
                          Text('No cards yet. Tap + to add your first card.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: c.cards.length,
                      itemBuilder: (_, i) =>
                          _CardTile(card: c.cards[i], controller: c),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _BestCardLookup extends StatefulWidget {
  const _BestCardLookup({required this.controller});
  final CashbackController controller;

  @override
  State<_BestCardLookup> createState() => _BestCardLookupState();
}

class _BestCardLookupState extends State<_BestCardLookup> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _ctrl.text.trim().isEmpty
        ? null
        : widget.controller.bestCardFor(_ctrl.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'What are you buying?',
              hintText: 'e.g. Groceries, Gas, Dining',
              prefixIcon: Icon(Icons.shopping_bag_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.credit_card,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use ${result.$1.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${result.$2.toStringAsFixed(1)}% on ${result.$3}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_ctrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No matching card found.'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.controller});
  final RewardsCard card;
  final CashbackController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = card.categories;

    return Dismissible(
      key: ValueKey(card.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(card),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => _showCardSheet(context, controller, existing: card),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card,
                        color: card.active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: card.active
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (card.isDefault)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Switch(
                      value: card.active,
                      onChanged: (_) => controller.toggleActive(card),
                    ),
                  ],
                ),
                if (card.annualFee > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '\$${card.annualFee.toStringAsFixed(0)} annual fee'
                      '${card.apr != null ? ' • ${card.apr}% APR' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (card.activeRotatingCategory != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rotating: ${card.activeRotatingCategory}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: cats
                        .map((entry) => Chip(
                              label: Text(
                                  '${entry.$1} ${entry.$2.toStringAsFixed(1)}%'),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
                if (card.notes != null && card.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(card.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showCardSheet(BuildContext context, CashbackController c,
    {RewardsCard? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CardSheetContent(controller: c, existing: existing),
  );
}

class _CardSheetContent extends StatefulWidget {
  const _CardSheetContent({required this.controller, this.existing});
  final CashbackController controller;
  final RewardsCard? existing;

  @override
  State<_CardSheetContent> createState() => _CardSheetContentState();
}

class _CardSheetContentState extends State<_CardSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoriesCtrl;
  late final TextEditingController _rotatingCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _aprCtrl;
  late bool _isDefault;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _categoriesCtrl =
        TextEditingController(text: widget.existing?.categoriesRaw ?? '');
    _rotatingCtrl = TextEditingController(
        text: widget.existing?.activeRotatingCategory ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _feeCtrl = TextEditingController(
        text: (widget.existing?.annualFee ?? 0) > 0
            ? widget.existing!.annualFee.toString()
            : '');
    _aprCtrl = TextEditingController(
        text: widget.existing?.apr?.toString() ?? '');
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoriesCtrl.dispose();
    _rotatingCtrl.dispose();
    _notesCtrl.dispose();
    _feeCtrl.dispose();
    _aprCtrl.dispose();
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
            Text(_isEdit ? 'Edit card' : 'New card',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Card name',
                hintText: 'e.g. Chase Sapphire, Amex Gold',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoriesCtrl,
              decoration: const InputDecoration(
                labelText: 'Categories',
                helperText: 'One per line: Category|Percent',
                hintText: 'Groceries|5\nGas|3\nDining|2\nEverything else|1',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 10,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rotatingCtrl,
              decoration: const InputDecoration(
                labelText: 'Active rotating category (optional)',
                hintText: 'For Discover/Chase Freedom rotating quarters',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Annual fee',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _aprCtrl,
                    decoration: const InputDecoration(
                      labelText: 'APR',
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use as default card'),
              subtitle: const Text(
                  'Worth-it analyzer compares other cards against this one'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
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
    if (name.isEmpty) return;
    final fee = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    final apr = double.tryParse(_aprCtrl.text.trim());
    if (_isEdit) {
      final card = widget.existing!;
      card.name = name;
      card.categoriesRaw = _categoriesCtrl.text;
      card.activeRotatingCategory = _rotatingCtrl.text.trim().isEmpty
          ? null
          : _rotatingCtrl.text.trim();
      card.notes =
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      card.annualFee = fee;
      card.apr = apr;
      card.isDefault = _isDefault;
      widget.controller.updateCard(card);
    } else {
      widget.controller.add(
        name: name,
        categoriesRaw: _categoriesCtrl.text,
        activeRotatingCategory: _rotatingCtrl.text,
        notes: _notesCtrl.text,
        annualFee: fee,
        apr: apr,
        isDefault: _isDefault,
      );
    }
    Navigator.pop(context);
  }
}
