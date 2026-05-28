import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class BankrollController extends GetxController {
  final _box = ObjectBox.instance.betRecordBox;
  final bets = <BetRecord>[].obs;

  /// "all", "open", "settled".
  final filter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    bets.assignAll(all);
  }

  List<BetRecord> get filtered {
    if (filter.value == 'open') {
      return bets.where((b) => b.status == 'open').toList();
    }
    if (filter.value == 'settled') {
      return bets.where((b) => b.status != 'open').toList();
    }
    return bets;
  }

  /// Stats for settled bets only.
  ({int wins, int losses, int pushes, double totalStaked, double totalReturn, double netProfit, double roi, double winRate}) get stats {
    final settled = bets.where((b) => b.status != 'open').toList();
    var wins = 0;
    var losses = 0;
    var pushes = 0;
    var totalStaked = 0.0;
    var netProfit = 0.0;
    for (final b in settled) {
      totalStaked += b.stake;
      netProfit += b.result;
      switch (b.status) {
        case 'won':
          wins++;
          break;
        case 'lost':
          losses++;
          break;
        case 'push':
        case 'void':
          pushes++;
          break;
      }
    }
    final totalReturn = totalStaked + netProfit;
    final roi = totalStaked > 0 ? (netProfit / totalStaked) * 100 : 0.0;
    final decided = wins + losses;
    final winRate = decided > 0 ? (wins / decided) * 100 : 0.0;
    return (
      wins: wins,
      losses: losses,
      pushes: pushes,
      totalStaked: totalStaked,
      totalReturn: totalReturn,
      netProfit: netProfit,
      roi: roi,
      winRate: winRate,
    );
  }

  /// Total stake of all open bets.
  double get openExposure {
    return bets
        .where((b) => b.status == 'open')
        .fold<double>(0, (s, b) => s + b.stake);
  }

  void add({
    required String description,
    String? sport,
    String? sportsbook,
    required double stake,
    required double decimalOdds,
    String? notes,
  }) {
    _box.put(BetRecord(
      description: description.trim(),
      sport: sport?.trim().isEmpty ?? true ? null : sport!.trim(),
      sportsbook:
          sportsbook?.trim().isEmpty ?? true ? null : sportsbook!.trim(),
      stake: stake,
      decimalOdds: decimalOdds,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    ));
    _load();
  }

  void updateBet(BetRecord bet) {
    _box.put(bet);
    _load();
    bets.refresh();
  }

  void settle(BetRecord bet, String status) {
    bet.status = status;
    bet.settledAt = DateTime.now();
    _box.put(bet);
    _load();
    bets.refresh();
  }

  void remove(BetRecord bet) {
    _box.remove(bet.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _americanToDecimal(String input) {
  final am = double.tryParse(input.trim());
  if (am == null || am == 0) return null;
  if (am > 0) return (am / 100) + 1;
  return (100 / am.abs()) + 1;
}

String _decimalToAmerican(double d) {
  if (d <= 1) return '—';
  if (d >= 2) {
    return '+${((d - 1) * 100).round()}';
  }
  return (-100 / (d - 1)).round().toString();
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class BankrollTrackerPage extends StatelessWidget {
  const BankrollTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(BankrollController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Bankroll')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBetSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        return Column(
          children: [
            _StatsCard(controller: c),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: c.filter.value == 'all',
                    onSelected: (_) => c.filter.value = 'all',
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Open'),
                    selected: c.filter.value == 'open',
                    onSelected: (_) => c.filter.value = 'open',
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Settled'),
                    selected: c.filter.value == 'settled',
                    onSelected: (_) => c.filter.value = 'settled',
                  ),
                ],
              ),
            ),
            Expanded(
              child: c.filtered.isEmpty
                  ? const Center(child: Text('No bets yet. Tap + to log one.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: c.filtered.length,
                      itemBuilder: (_, i) =>
                          _BetTile(bet: c.filtered[i], controller: c),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.controller});
  final BankrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final s = controller.stats;
    final profitColor = s.netProfit >= 0 ? Colors.green : theme.colorScheme.error;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '${s.netProfit >= 0 ? '+' : ''}${fmt.format(s.netProfit)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('net profit', style: theme.textTheme.bodySmall),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${s.roi >= 0 ? '+' : ''}${s.roi.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('ROI', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniStat(value: '${s.wins}-${s.losses}', label: 'record'),
                _MiniStat(
                    value: '${s.winRate.toStringAsFixed(0)}%',
                    label: 'win rate'),
                if (controller.openExposure > 0)
                  _MiniStat(
                    value: fmt.format(controller.openExposure),
                    label: 'open',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _BetTile extends StatelessWidget {
  const _BetTile({required this.bet, required this.controller});
  final BetRecord bet;
  final BankrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat.MMMd();

    Color? badgeColor;
    Color? badgeFg;
    String? badgeText;
    switch (bet.status) {
      case 'won':
        badgeColor = Colors.green;
        badgeFg = Colors.white;
        badgeText = 'WON';
        break;
      case 'lost':
        badgeColor = theme.colorScheme.error;
        badgeFg = theme.colorScheme.onError;
        badgeText = 'LOST';
        break;
      case 'push':
        badgeColor = theme.colorScheme.surfaceContainerHighest;
        badgeFg = theme.colorScheme.onSurfaceVariant;
        badgeText = 'PUSH';
        break;
      case 'void':
        badgeColor = theme.colorScheme.surfaceContainerHighest;
        badgeFg = theme.colorScheme.onSurfaceVariant;
        badgeText = 'VOID';
        break;
    }

    return Dismissible(
      key: ValueKey(bet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(bet),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => _showBetSheet(context, controller, existing: bet),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bet.description,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: badgeFg),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (bet.sport != null) bet.sport!,
                    '${fmt.format(bet.stake)} @ ${_decimalToAmerican(bet.decimalOdds)}',
                    if (bet.sportsbook != null) bet.sportsbook!,
                    dateFmt.format(bet.placedAt),
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (bet.status == 'open')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'To win: ${fmt.format(bet.potentialProfit)} '
                      '→ ${fmt.format(bet.potentialPayout)} payout',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      bet.status == 'won'
                          ? '+${fmt.format(bet.result)}'
                          : bet.status == 'lost'
                              ? '${fmt.format(bet.result)}'
                              : '${fmt.format(bet.result)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bet.result > 0
                            ? Colors.green
                            : bet.result < 0
                                ? theme.colorScheme.error
                                : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (bet.status == 'open') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Won'),
                        onPressed: () => controller.settle(bet, 'won'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Lost'),
                        onPressed: () => controller.settle(bet, 'lost'),
                      ),
                      TextButton(
                        onPressed: () => controller.settle(bet, 'push'),
                        child: const Text('Push'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showBetSheet(BuildContext context, BankrollController c,
    {BetRecord? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _BetSheetContent(controller: c, existing: existing),
  );
}

class _BetSheetContent extends StatefulWidget {
  const _BetSheetContent({required this.controller, this.existing});
  final BankrollController controller;
  final BetRecord? existing;

  @override
  State<_BetSheetContent> createState() => _BetSheetContentState();
}

class _BetSheetContentState extends State<_BetSheetContent> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _sportCtrl;
  late final TextEditingController _bookCtrl;
  late final TextEditingController _stakeCtrl;
  late final TextEditingController _oddsCtrl;
  late final TextEditingController _notesCtrl;
  String _oddsFormat = 'american';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _sportCtrl =
        TextEditingController(text: widget.existing?.sport ?? '');
    _bookCtrl =
        TextEditingController(text: widget.existing?.sportsbook ?? '');
    _stakeCtrl = TextEditingController(
        text: widget.existing?.stake.toString() ?? '');
    _oddsCtrl = TextEditingController(
        text: widget.existing != null
            ? _decimalToAmerican(widget.existing!.decimalOdds)
            : '');
    _notesCtrl =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _sportCtrl.dispose();
    _bookCtrl.dispose();
    _stakeCtrl.dispose();
    _oddsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parseOdds() {
    if (_oddsFormat == 'american') return _americanToDecimal(_oddsCtrl.text);
    if (_oddsFormat == 'percent') {
      final pct = double.tryParse(_oddsCtrl.text.trim());
      if (pct == null || pct <= 0 || pct >= 100) return null;
      return 100 / pct;
    }
    return double.tryParse(_oddsCtrl.text.trim());
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
            Text(_isEdit ? 'Edit bet' : 'Log bet',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Lakers ML, Over 220.5',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sport (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bookCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sportsbook',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stakeCtrl,
              decoration: const InputDecoration(
                labelText: 'Stake',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'american', label: Text('American')),
                ButtonSegment(value: 'decimal', label: Text('Decimal')),
                ButtonSegment(value: 'percent', label: Text('Percent')),
              ],
              selected: {_oddsFormat},
              onSelectionChanged: (s) => setState(() => _oddsFormat = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _oddsCtrl,
              decoration: InputDecoration(
                labelText: 'Odds',
                hintText: switch (_oddsFormat) {
                  'american' => 'e.g. -110, +200',
                  'decimal' => 'e.g. 1.91, 3.00',
                  'percent' => 'e.g. 80, 52.5',
                  _ => '',
                },
                suffixText: _oddsFormat == 'percent' ? '%' : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
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
    final desc = _descCtrl.text.trim();
    final stake = double.tryParse(_stakeCtrl.text.trim());
    final decimalOdds = _parseOdds();
    if (desc.isEmpty || stake == null || stake <= 0 || decimalOdds == null ||
        decimalOdds <= 1) {
      return;
    }

    if (_isEdit) {
      final bet = widget.existing!;
      bet.description = desc;
      bet.sport = _sportCtrl.text.trim().isEmpty ? null : _sportCtrl.text.trim();
      bet.sportsbook =
          _bookCtrl.text.trim().isEmpty ? null : _bookCtrl.text.trim();
      bet.stake = stake;
      bet.decimalOdds = decimalOdds;
      bet.notes =
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      widget.controller.updateBet(bet);
    } else {
      widget.controller.add(
        description: desc,
        sport: _sportCtrl.text,
        sportsbook: _bookCtrl.text,
        stake: stake,
        decimalOdds: decimalOdds,
        notes: _notesCtrl.text,
      );
    }
    Navigator.pop(context);
  }
}
