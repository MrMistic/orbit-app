import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Vig (juice) calculator. Computes the bookmaker margin from two-sided odds
/// and shows the implied probabilities and no-vig "fair" odds.
class VigCalculatorPage extends StatefulWidget {
  const VigCalculatorPage({super.key});

  @override
  State<VigCalculatorPage> createState() => _VigCalculatorPageState();
}

class _VigCalculatorPageState extends State<VigCalculatorPage> {
  /// "american" or "decimal".
  String _oddsFormat = 'american';

  final _odds1Ctrl = TextEditingController();
  final _odds2Ctrl = TextEditingController();

  @override
  void dispose() {
    _odds1Ctrl.dispose();
    _odds2Ctrl.dispose();
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

  /// Convert a fair probability (0..1) to American odds.
  String _probabilityToAmerican(double p) {
    if (p <= 0 || p >= 1) return '—';
    final decimal = 1 / p;
    return _decimalToAmerican(decimal);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dec1 = _parseOdds(_odds1Ctrl.text);
    final dec2 = _parseOdds(_odds2Ctrl.text);

    _VigResult? result;
    if (dec1 != null && dec1 > 1 && dec2 != null && dec2 > 1) {
      final p1 = 1 / dec1;
      final p2 = 1 / dec2;
      final sum = p1 + p2;
      final vigPct = (sum - 1) * 100;
      final fair1 = p1 / sum;
      final fair2 = p2 / sum;
      result = _VigResult(
        impliedProb1: p1 * 100,
        impliedProb2: p2 * 100,
        vigPercent: vigPct,
        noVigDecimal1: 1 / fair1,
        noVigDecimal2: 1 / fair2,
        noVigAmerican1: _probabilityToAmerican(fair1),
        noVigAmerican2: _probabilityToAmerican(fair2),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vig calculator')),
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
          _OddsField(
            controller: _odds1Ctrl,
            label: 'Side 1 odds',
            format: _oddsFormat,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _OddsField(
            controller: _odds2Ctrl,
            label: 'Side 2 odds',
            format: _oddsFormat,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Enter odds for both sides to see the vig and fair (no-vig) lines.',
                ),
              ),
            )
          else
            _ResultCard(result: result, oddsFormat: _oddsFormat),
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
  const _ResultCard({required this.result, required this.oddsFormat});
  final _VigResult result;
  final String oddsFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pctFmt = NumberFormat('0.00');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vig', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${pctFmt.format(result.vigPercent)}%',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Text('Implied probability',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Side 1', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${pctFmt.format(result.impliedProb1)}%',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('Side 2', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${pctFmt.format(result.impliedProb2)}%',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const Divider(height: 24),
            Text('No-vig fair odds', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Side 1', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  oddsFormat == 'american'
                      ? result.noVigAmerican1
                      : result.noVigDecimal1.toStringAsFixed(3),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('Side 2', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  oddsFormat == 'american'
                      ? result.noVigAmerican2
                      : result.noVigDecimal2.toStringAsFixed(3),
                  style: theme.textTheme.titleSmall,
                ),
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
              'Vig (or juice) is the bookmaker\'s margin baked into the line. '
              'Each side\'s implied probability equals 1 / decimal odds. The '
              'sum of both implied probabilities is greater than 100% — that '
              'excess is the vig.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'No-vig fair odds rescale each implied probability so the two '
              'sides sum to exactly 100%, showing the true line if there were '
              'no margin.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _VigResult {
  const _VigResult({
    required this.impliedProb1,
    required this.impliedProb2,
    required this.vigPercent,
    required this.noVigDecimal1,
    required this.noVigDecimal2,
    required this.noVigAmerican1,
    required this.noVigAmerican2,
  });

  final double impliedProb1;
  final double impliedProb2;
  final double vigPercent;
  final double noVigDecimal1;
  final double noVigDecimal2;
  final String noVigAmerican1;
  final String noVigAmerican2;
}
