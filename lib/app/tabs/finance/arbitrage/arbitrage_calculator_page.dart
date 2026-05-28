import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Arbitrage calculator for 2-way and 3-way sports bets.
///
/// Math:
///   - Decimal odds = American odds converted: positive = (am/100) + 1,
///     negative = (100/abs(am)) + 1
///   - Arb exists when sum of inverse decimal odds < 1
///   - Each stake = totalStake × (1/dec_outcome) / sum(1/dec_outcomes)
///   - Profit = totalStake × (1 / sum(1/dec_outcomes) - 1)
class ArbitrageCalculatorPage extends StatefulWidget {
  const ArbitrageCalculatorPage({super.key});

  @override
  State<ArbitrageCalculatorPage> createState() =>
      _ArbitrageCalculatorPageState();
}

class _ArbitrageCalculatorPageState extends State<ArbitrageCalculatorPage> {
  /// "american", "decimal", or "percent".
  String _oddsFormat = 'american';

  /// 2 or 3.
  int _numOutcomes = 2;

  final _stakeCtrl = TextEditingController(text: '100');
  final _odds1Ctrl = TextEditingController();
  final _odds2Ctrl = TextEditingController();
  final _odds3Ctrl = TextEditingController();

  @override
  void dispose() {
    _stakeCtrl.dispose();
    _odds1Ctrl.dispose();
    _odds2Ctrl.dispose();
    _odds3Ctrl.dispose();
    super.dispose();
  }

  /// Convert American odds to decimal. Returns null if invalid.
  double? _americanToDecimal(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final am = double.tryParse(trimmed);
    if (am == null || am == 0) return null;
    if (am > 0) return (am / 100) + 1;
    return (100 / am.abs()) + 1;
  }

  /// Parse odds based on current format.
  double? _parseOdds(String input) {
    if (_oddsFormat == 'american') return _americanToDecimal(input);
    if (_oddsFormat == 'percent') {
      final pct = double.tryParse(input.trim());
      if (pct == null || pct <= 0 || pct >= 100) return null;
      return 100 / pct;
    }
    return double.tryParse(input.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final stake = double.tryParse(_stakeCtrl.text.trim());
    final ctrls = [_odds1Ctrl, _odds2Ctrl, _odds3Ctrl].take(_numOutcomes).toList();
    final decimals = ctrls.map((c) => _parseOdds(c.text)).toList();

    // Calculate.
    _ArbResult? result;
    final allValid = decimals.every((d) => d != null && d > 1);
    if (allValid && stake != null && stake > 0) {
      final inverseSum =
          decimals.fold<double>(0, (sum, d) => sum + (1 / d!));
      final stakes = decimals
          .map((d) => stake * (1 / d!) / inverseSum)
          .toList();
      final payout = stake / inverseSum;
      final profit = payout - stake;
      final profitPercent = (profit / stake) * 100;
      result = _ArbResult(
        stakes: stakes,
        payout: payout,
        profit: profit,
        profitPercent: profitPercent,
        isArb: inverseSum < 1,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Arbitrage calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Format toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'american', label: Text('American')),
              ButtonSegment(value: 'decimal', label: Text('Decimal')),
              ButtonSegment(value: 'percent', label: Text('Percent')),
            ],
            selected: {_oddsFormat},
            onSelectionChanged: (s) => setState(() => _oddsFormat = s.first),
          ),
          const SizedBox(height: 12),
          // Outcomes count
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2 outcomes')),
              ButtonSegment(value: 3, label: Text('3 outcomes')),
            ],
            selected: {_numOutcomes},
            onSelectionChanged: (s) => setState(() => _numOutcomes = s.first),
          ),
          const SizedBox(height: 16),
          // Total stake
          TextField(
            controller: _stakeCtrl,
            decoration: const InputDecoration(
              labelText: 'Total stake',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Odds', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _OddsField(
            controller: _odds1Ctrl,
            label: 'Outcome 1',
            format: _oddsFormat,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          _OddsField(
            controller: _odds2Ctrl,
            label: 'Outcome 2',
            format: _oddsFormat,
            onChanged: () => setState(() {}),
          ),
          if (_numOutcomes == 3) ...[
            const SizedBox(height: 8),
            _OddsField(
              controller: _odds3Ctrl,
              label: 'Outcome 3',
              format: _oddsFormat,
              onChanged: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 24),
          // Result
          if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Enter total stake and odds for each outcome to see if there\'s an arbitrage opportunity.',
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

class _OddsField extends StatelessWidget {
  const _OddsField({
    required this.controller,
    required this.label,
    required this.format,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String format;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: switch (format) {
          'american' => 'e.g. -110, +200',
          'decimal' => 'e.g. 1.91, 3.00',
          'percent' => 'e.g. 80, 52.5',
          _ => '',
        },
        suffixText: format == 'percent' ? '%' : null,
        border: const OutlineInputBorder(),
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (_) => onChanged(),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.fmt});
  final _ArbResult result;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArb = result.isArb;
    final color = isArb ? Colors.green : theme.colorScheme.error;
    return Card(
      color: isArb
          ? Colors.green.withValues(alpha: 0.1)
          : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isArb ? Icons.check_circle : Icons.warning_amber,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isArb ? 'Arbitrage found' : 'No arbitrage',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Per-outcome stakes
            for (var i = 0; i < result.stakes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('Outcome ${i + 1}',
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      'Bet ${fmt.format(result.stakes[i])}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Text('Guaranteed payout',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.payout),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Profit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const Spacer(),
                Text(
                  '${result.profit >= 0 ? '+' : ''}${fmt.format(result.profit)} '
                  '(${result.profitPercent.toStringAsFixed(2)}%)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (!isArb) ...[
              const SizedBox(height: 8),
              Text(
                'These odds combine to a negative expected value. Look for better lines.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
              'An arbitrage exists when the implied probabilities of all outcomes '
              'sum to less than 100%. The calculator splits your stake so each '
              'outcome returns the same payout, locking in profit regardless of '
              'which outcome wins.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Tip: bet on different outcomes at different sportsbooks for the '
              'best chance of finding arbs.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArbResult {
  const _ArbResult({
    required this.stakes,
    required this.payout,
    required this.profit,
    required this.profitPercent,
    required this.isArb,
  });

  final List<double> stakes;
  final double payout;
  final double profit;
  final double profitPercent;
  final bool isArb;
}
