import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Static reference for US 2025 federal income tax brackets, with an
/// optional tax estimator for a given taxable income.
class TaxBracketReferencePage extends StatefulWidget {
  const TaxBracketReferencePage({super.key});

  @override
  State<TaxBracketReferencePage> createState() =>
      _TaxBracketReferencePageState();
}

class _TaxBracketReferencePageState extends State<TaxBracketReferencePage> {
  final _incomeCtrl = TextEditingController();

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final income = double.tryParse(_incomeCtrl.text.trim());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('2025 federal tax brackets'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Single'),
              Tab(text: 'MFJ'),
              Tab(text: 'HOH'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _incomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your taxable income (optional)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BracketTab(brackets: _singleBrackets, income: income),
                  _BracketTab(brackets: _mfjBrackets, income: income),
                  _BracketTab(brackets: _hohBrackets, income: income),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketTab extends StatelessWidget {
  const _BracketTab({required this.brackets, required this.income});
  final List<_Bracket> brackets;
  final double? income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency(decimalDigits: 0);

    _TaxResult? taxResult;
    if (income != null && income! > 0) {
      taxResult = _computeTax(income!, brackets);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (taxResult != null) ...[
          _TaxResultCard(income: income!, result: taxResult),
          const SizedBox(height: 16),
        ],
        Text('Brackets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < brackets.length; i++) ...[
                  _BracketRow(
                    bracket: brackets[i],
                    lowerBound: i == 0 ? 0 : brackets[i - 1].upperBound!,
                    fmt: fmt,
                    highlighted:
                        taxResult != null && taxResult.marginalIndex == i,
                  ),
                  if (i < brackets.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(),
      ],
    );
  }
}

class _BracketRow extends StatelessWidget {
  const _BracketRow({
    required this.bracket,
    required this.lowerBound,
    required this.fmt,
    required this.highlighted,
  });

  final _Bracket bracket;
  final double lowerBound;
  final NumberFormat fmt;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upper = bracket.upperBound;
    final rangeText = upper == null
        ? 'over ${fmt.format(lowerBound)}'
        : lowerBound == 0
            ? 'up to ${fmt.format(upper)}'
            : '${fmt.format(lowerBound)} – ${fmt.format(upper)}';
    return Container(
      color: highlighted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '${(bracket.rate * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: highlighted ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              rangeText,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'your bracket',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaxResultCard extends StatelessWidget {
  const _TaxResultCard({required this.income, required this.result});
  final double income;
  final _TaxResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();
    final pctFmt = NumberFormat('0.00');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimated federal tax', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              fmt.format(result.totalTax),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Taxable income', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(income),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Effective tax rate',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${pctFmt.format(result.effectiveRate * 100)}%',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Marginal rate', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${(result.marginalRate * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Take-home (after federal)',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(income - result.totalTax),
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
              'US federal income tax is progressive. Each bracket\'s rate '
              'applies only to the portion of income that falls inside that '
              'bracket — not your whole income. Your effective rate is total '
              'tax divided by taxable income; your marginal rate is the rate '
              'on your last dollar earned.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'This estimate uses 2025 federal brackets only. It does not '
              'include state tax, FICA, deductions, or credits.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

_TaxResult _computeTax(double income, List<_Bracket> brackets) {
  var tax = 0.0;
  var lower = 0.0;
  var marginalIndex = 0;
  var marginalRate = brackets.first.rate;
  for (var i = 0; i < brackets.length; i++) {
    final b = brackets[i];
    final upper = b.upperBound ?? double.infinity;
    if (income <= lower) break;
    final taxableInBracket =
        (income < upper ? income : upper) - lower;
    tax += taxableInBracket * b.rate;
    marginalIndex = i;
    marginalRate = b.rate;
    if (income <= upper) break;
    lower = upper;
  }
  return _TaxResult(
    totalTax: tax,
    effectiveRate: income > 0 ? tax / income : 0,
    marginalRate: marginalRate,
    marginalIndex: marginalIndex,
  );
}

class _Bracket {
  const _Bracket({required this.rate, required this.upperBound});

  /// Decimal rate (e.g. 0.10 for 10%).
  final double rate;

  /// Upper bound of this bracket. `null` means "no upper bound" (top bracket).
  final double? upperBound;
}

class _TaxResult {
  const _TaxResult({
    required this.totalTax,
    required this.effectiveRate,
    required this.marginalRate,
    required this.marginalIndex,
  });

  final double totalTax;
  final double effectiveRate;
  final double marginalRate;
  final int marginalIndex;
}

// 2025 federal income tax brackets.
const List<_Bracket> _singleBrackets = [
  _Bracket(rate: 0.10, upperBound: 11925),
  _Bracket(rate: 0.12, upperBound: 48475),
  _Bracket(rate: 0.22, upperBound: 103350),
  _Bracket(rate: 0.24, upperBound: 197300),
  _Bracket(rate: 0.32, upperBound: 250525),
  _Bracket(rate: 0.35, upperBound: 626350),
  _Bracket(rate: 0.37, upperBound: null),
];

const List<_Bracket> _mfjBrackets = [
  _Bracket(rate: 0.10, upperBound: 23850),
  _Bracket(rate: 0.12, upperBound: 96950),
  _Bracket(rate: 0.22, upperBound: 206700),
  _Bracket(rate: 0.24, upperBound: 394600),
  _Bracket(rate: 0.32, upperBound: 501050),
  _Bracket(rate: 0.35, upperBound: 751600),
  _Bracket(rate: 0.37, upperBound: null),
];

const List<_Bracket> _hohBrackets = [
  _Bracket(rate: 0.10, upperBound: 17000),
  _Bracket(rate: 0.12, upperBound: 64850),
  _Bracket(rate: 0.22, upperBound: 103350),
  _Bracket(rate: 0.24, upperBound: 197300),
  _Bracket(rate: 0.32, upperBound: 250500),
  _Bracket(rate: 0.35, upperBound: 626350),
  _Bracket(rate: 0.37, upperBound: null),
];
