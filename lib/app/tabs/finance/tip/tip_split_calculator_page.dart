import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Tip split calculator. Computes tip, total, and per-person amount.
class TipSplitCalculatorPage extends StatefulWidget {
  const TipSplitCalculatorPage({super.key});

  @override
  State<TipSplitCalculatorPage> createState() => _TipSplitCalculatorPageState();
}

class _TipSplitCalculatorPageState extends State<TipSplitCalculatorPage> {
  final _billCtrl = TextEditingController();
  double _tipPercent = 18;
  int _people = 2;

  @override
  void dispose() {
    _billCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final bill = double.tryParse(_billCtrl.text.trim());
    _TipResult? result;
    if (bill != null && bill > 0 && _people > 0) {
      final tip = bill * (_tipPercent / 100);
      final total = bill + tip;
      final perPerson = total / _people;
      result = _TipResult(
        tip: tip,
        total: total,
        perPerson: perPerson,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tip split calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _billCtrl,
            decoration: const InputDecoration(
              labelText: 'Bill amount',
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
              Text('Tip', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${_tipPercent.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          Slider(
            value: _tipPercent,
            min: 0,
            max: 30,
            divisions: 30,
            label: '${_tipPercent.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _tipPercent = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('People', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '$_people',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          Slider(
            value: _people.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            label: '$_people',
            onChanged: (v) => setState(() => _people = v.round()),
          ),
          const SizedBox(height: 16),
          if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Enter a bill amount to see how to split it.'),
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
  final _TipResult result;
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
            Text('Each person pays', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              fmt.format(result.perPerson),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Tip', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.tip),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Total bill', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.total),
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
              'Tip is calculated on the pre-tax bill amount. The total bill '
              '(bill plus tip) is divided evenly across the number of people.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Common tip ranges: 15% (standard), 18-20% (good service), '
              '20%+ (great service).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipResult {
  const _TipResult({
    required this.tip,
    required this.total,
    required this.perPerson,
  });

  final double tip;
  final double total;
  final double perPerson;
}
