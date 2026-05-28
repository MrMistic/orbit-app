import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Parlay calculator. Computes combined odds, payout, and profit for
/// a multi-leg parlay bet.
class ParlayCalculatorPage extends StatefulWidget {
  const ParlayCalculatorPage({super.key});

  @override
  State<ParlayCalculatorPage> createState() => _ParlayCalculatorPageState();
}

class _ParlayCalculatorPageState extends State<ParlayCalculatorPage> {
  static const int _minLegs = 2;
  static const int _maxLegs = 10;

  String _oddsFormat = 'american';
  final _stakeCtrl = TextEditingController(text: '100');
  final List<TextEditingController> _legCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _stakeCtrl.dispose();
    for (final c in _legCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  double? _americanToDecimal(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final am = double.tryParse(trimmed);
    if (am == null || am == 0) return null;
    if (am > 0) return (am / 100) + 1;
    return (100 / am.abs()) + 1;
  }

  double? _parseOdds(String input) {
    if (_oddsFormat == 'american') return _americanToDecimal(input);
    if (_oddsFormat == 'percent') {
      final pct = double.tryParse(input.trim());
      if (pct == null || pct <= 0 || pct >= 100) return null;
      return 100 / pct;
    }
    return double.tryParse(input.trim());
  }

  String _decimalToAmerican(double d) {
    if (d <= 1) return '—';
    if (d >= 2) {
      final am = (d - 1) * 100;
      return '+${am.round()}';
    }
    final am = -100 / (d - 1);
    return am.round().toString();
  }

  void _addLeg() {
    if (_legCtrls.length >= _maxLegs) return;
    setState(() => _legCtrls.add(TextEditingController()));
  }

  void _removeLeg(int index) {
    if (_legCtrls.length <= _minLegs) return;
    setState(() {
      _legCtrls.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final stake = double.tryParse(_stakeCtrl.text.trim());
    final decimals = _legCtrls.map((c) => _parseOdds(c.text)).toList();

    _ParlayResult? result;
    final allValid = decimals.every((d) => d != null && d > 1);
    if (allValid && stake != null && stake > 0) {
      var combined = 1.0;
      for (final d in decimals) {
        combined *= d!;
      }
      final payout = stake * combined;
      final profit = payout - stake;
      result = _ParlayResult(
        combinedDecimal: combined,
        americanEquivalent: _decimalToAmerican(combined),
        payout: payout,
        profit: profit,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Parlay calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'american', label: Text('American')),
              ButtonSegment(value: 'decimal', label: Text('Decimal')),
              ButtonSegment(value: 'percent', label: Text('Percent')),
            ],
            selected: {_oddsFormat},
            onSelectionChanged: (s) => setState(() => _oddsFormat = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stakeCtrl,
            decoration: const InputDecoration(
              labelText: 'Stake',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Legs', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text('${_legCtrls.length}/$_maxLegs',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _legCtrls.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _legCtrls[i],
                    decoration: InputDecoration(
                      labelText: 'Leg ${i + 1}',
                      hintText: switch (_oddsFormat) {
                        'american' => 'e.g. -110, +200',
                        'decimal' => 'e.g. 1.91, 3.00',
                        'percent' => 'e.g. 80, 52.5',
                        _ => '',
                      },
                      suffixText: _oddsFormat == 'percent' ? '%' : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _legCtrls.length > _minLegs
                      ? () => _removeLeg(i)
                      : null,
                  tooltip: 'Remove leg',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _legCtrls.length < _maxLegs ? _addLeg : null,
              icon: const Icon(Icons.add),
              label: const Text('Add leg'),
            ),
          ),
          const SizedBox(height: 16),
          if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Enter your stake and odds for each leg to see the parlay payout.',
                ),
              ),
            )
          else
            _ResultCard(result: result, fmt: fmt),
          const SizedBox(height: 16),
          _InfoCard(),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.fmt});
  final _ParlayResult result;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total payout', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              fmt.format(result.payout),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Profit', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.profit),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Combined decimal odds',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(result.combinedDecimal.toStringAsFixed(3),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Equivalent American odds',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(result.americanEquivalent,
                    style: theme.textTheme.titleSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('How it works',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A parlay combines multiple bets into one. Combined decimal odds '
              'are the product of every leg\'s decimal odds. Total payout '
              'equals stake × combined odds; profit is payout minus stake.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'All legs must win for the parlay to pay out. Each added leg '
              'multiplies the potential payout but also multiplies the risk.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParlayResult {
  const _ParlayResult({
    required this.combinedDecimal,
    required this.americanEquivalent,
    required this.payout,
    required this.profit,
  });

  final double combinedDecimal;
  final String americanEquivalent;
  final double payout;
  final double profit;
}
