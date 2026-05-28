import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Worth-It Analyzer
// ---------------------------------------------------------------------------

class WorthItAnalyzerPage extends StatefulWidget {
  const WorthItAnalyzerPage({super.key});

  @override
  State<WorthItAnalyzerPage> createState() => _WorthItAnalyzerPageState();
}

class _WorthItAnalyzerPageState extends State<WorthItAnalyzerPage> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final cards = ObjectBox.instance.rewardsCardBox.getAll()
      ..sort((a, b) => a.name.compareTo(b.name));
    final feeCards = cards.where((c) => c.annualFee > 0 && c.active).toList();
    final defaultCard = cards.firstWhereOrNull((c) => c.isDefault);
    final spending = _loadSpending();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card worth-it analyzer'),
        actions: [
          IconButton(
            tooltip: 'Edit spending profile',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        SpendingProfilePage(allCategories: _allCategories(cards))),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (spending.isEmpty)
            _SetupHint(
              onSetup: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SpendingProfilePage(
                        allCategories: _allCategories(cards)),
                  ),
                );
                _refresh();
              },
            ),
          if (spending.isNotEmpty) ...[
            _SpendingSummary(spending: spending),
            const SizedBox(height: 16),
            if (defaultCard == null)
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mark one card as "default" in Cashback cards. The analyzer compares fee cards against it.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Comparing against default: ${defaultCard.name}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (feeCards.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No active cards with annual fees. Set an annual fee on a card to analyze it here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...feeCards.map((card) => _CardAnalysisTile(
                    card: card,
                    defaultCard: defaultCard,
                    spending: spending,
                    fmt: fmt,
                  )),
          ],
        ],
      ),
    );
  }

  Map<String, double> _loadSpending() {
    final entries = ObjectBox.instance.spendingProfileBox.getAll();
    final map = <String, double>{};
    for (final e in entries) {
      if (e.monthlySpend > 0) map[e.category] = e.monthlySpend;
    }
    return map;
  }

  List<String> _allCategories(List<RewardsCard> cards) {
    final set = <String>{
      'Groceries',
      'Gas',
      'Dining',
      'Travel',
      'Streaming',
      'Online shopping',
      'Drugstores',
      'Everything else',
    };
    for (final card in cards) {
      for (final (cat, _) in card.categories) {
        set.add(cat);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}

// ---------------------------------------------------------------------------
// Setup hint when no spending data exists yet
// ---------------------------------------------------------------------------

class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set up your spending profile',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tell the analyzer roughly how much you spend per month in each category. '
              'You can find these numbers in Quicken or your bank statements.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Set up spending profile'),
              onPressed: onSetup,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingSummary extends StatelessWidget {
  const _SpendingSummary({required this.spending});
  final Map<String, double> spending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final total = spending.values.fold<double>(0, (a, b) => a + b);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.shopping_bag_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total monthly spend: ${fmt.format(total)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${spending.length} categor${spending.length == 1 ? 'y' : 'ies'} configured',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card analysis tile
// ---------------------------------------------------------------------------

class _CardAnalysisTile extends StatelessWidget {
  const _CardAnalysisTile({
    required this.card,
    required this.defaultCard,
    required this.spending,
    required this.fmt,
  });

  final RewardsCard card;
  final RewardsCard? defaultCard;
  final Map<String, double> spending;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compute annual cashback for this card.
    var thisAnnualCashback = 0.0;
    var defaultAnnualCashback = 0.0;
    final breakdown = <(String, double, double, double)>[]; // category, spend, this%, default%
    for (final entry in spending.entries) {
      final cat = entry.key;
      final spend = entry.value;
      final thisPct = card.percentForCategory(cat);
      final defaultPct = defaultCard?.percentForCategory(cat) ?? 0;
      thisAnnualCashback += spend * 12 * (thisPct / 100);
      defaultAnnualCashback += spend * 12 * (defaultPct / 100);
      breakdown.add((cat, spend, thisPct, defaultPct));
    }

    final netVsFee = thisAnnualCashback - card.annualFee;
    // True comparison: how much more (or less) than the default card, after fee.
    final advantageVsDefault = thisAnnualCashback - defaultAnnualCashback - card.annualFee;
    final isWorthIt = advantageVsDefault > 0;
    final color = isWorthIt ? Colors.green : theme.colorScheme.error;

    // Compute break-even monthly spend in the card's best category.
    // If we already have a positive advantage, suggest current spending is enough.
    // Otherwise, find what extra spending in the highest-rate category would close the gap.
    String? breakEvenHint;
    if (!isWorthIt) {
      final cats = card.categories;
      if (cats.isNotEmpty) {
        final bestCat =
            cats.reduce((a, b) => a.$2 >= b.$2 ? a : b);
        final defaultPctForBestCat =
            defaultCard?.percentForCategory(bestCat.$1) ?? 0;
        final marginPerDollar = (bestCat.$2 - defaultPctForBestCat) / 100;
        if (marginPerDollar > 0) {
          final extraNeeded = -advantageVsDefault / marginPerDollar / 12;
          if (extraNeeded > 0) {
            breakEvenHint =
                'Need \$${extraNeeded.toStringAsFixed(0)}/mo more in ${bestCat.$1} '
                '(at ${bestCat.$2.toStringAsFixed(1)}%) to break even.';
          }
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(card.name,
                      style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${advantageVsDefault >= 0 ? '+' : ''}${fmt.format(advantageVsDefault)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isWorthIt ? 'Worth keeping' : 'Not worth it at current spending',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
            const SizedBox(height: 8),
            // Detail rows
            _AnalysisRow(
                label: 'Annual cashback (this card)',
                value: fmt.format(thisAnnualCashback)),
            if (defaultCard != null)
              _AnalysisRow(
                  label: 'Annual cashback (default card)',
                  value: fmt.format(defaultAnnualCashback)),
            _AnalysisRow(
                label: 'Annual fee',
                value: '−${fmt.format(card.annualFee)}'),
            const Divider(height: 16),
            _AnalysisRow(
              label: defaultCard != null
                  ? 'Net advantage vs default'
                  : 'Net value (cashback − fee)',
              value: '${advantageVsDefault >= 0 ? '+' : ''}${fmt.format(advantageVsDefault)}',
              bold: true,
              color: color,
            ),
            if (breakEvenHint != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: theme.colorScheme.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        breakEvenHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Category breakdown',
                  style: theme.textTheme.bodySmall),
              children: [
                for (final (cat, spend, thisPct, defaultPct) in breakdown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(cat,
                              style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(fmt.format(spend),
                              style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            defaultCard != null
                                ? '${thisPct.toStringAsFixed(1)}% vs ${defaultPct.toStringAsFixed(1)}%'
                                : '${thisPct.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
        ?.copyWith(color: color, fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spending Profile Page
// ---------------------------------------------------------------------------

class SpendingProfilePage extends StatefulWidget {
  const SpendingProfilePage({super.key, required this.allCategories});
  final List<String> allCategories;

  @override
  State<SpendingProfilePage> createState() => _SpendingProfilePageState();
}

class _SpendingProfilePageState extends State<SpendingProfilePage> {
  final _ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final existing = ObjectBox.instance.spendingProfileBox.getAll();
    final spendMap = <String, double>{
      for (final e in existing) e.category: e.monthlySpend,
    };
    for (final cat in widget.allCategories) {
      _ctrls[cat] = TextEditingController(
        text: spendMap[cat]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final box = ObjectBox.instance.spendingProfileBox;
    // Wipe and replace.
    final existingIds = box.getAll().map((e) => e.id).toList();
    if (existingIds.isNotEmpty) box.removeMany(existingIds);
    for (final entry in _ctrls.entries) {
      final spend = double.tryParse(entry.value.text.trim()) ?? 0;
      if (spend > 0) {
        box.put(SpendingProfileEntry(
          category: entry.key,
          monthlySpend: spend,
        ));
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending profile'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Roughly how much do you spend per month in each category? '
            'Leave blank or 0 to skip.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final cat in widget.allCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _ctrls[cat],
                decoration: InputDecoration(
                  labelText: cat,
                  prefixText: '\$ ',
                  suffixText: '/mo',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
