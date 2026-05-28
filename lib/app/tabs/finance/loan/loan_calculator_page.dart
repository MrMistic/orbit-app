import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Loan calculator. Computes monthly payment using standard amortization.
///
/// Formula: payment = P × (r(1+r)^n) / ((1+r)^n - 1)
/// where r is monthly interest rate, n is number of months.
class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key});

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _termCtrl = TextEditingController();

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final principal = double.tryParse(_principalCtrl.text.trim());
    final annualRate = double.tryParse(_rateCtrl.text.trim());
    final years = double.tryParse(_termCtrl.text.trim());

    _LoanResult? result;
    if (principal != null &&
        principal > 0 &&
        annualRate != null &&
        annualRate >= 0 &&
        years != null &&
        years > 0) {
      final n = years * 12;
      final r = (annualRate / 100) / 12;
      double monthly;
      if (r == 0) {
        monthly = principal / n;
      } else {
        final pow = math.pow(1 + r, n).toDouble();
        monthly = principal * (r * pow) / (pow - 1);
      }
      final totalCost = monthly * n;
      final totalInterest = totalCost - principal;
      result = _LoanResult(
        monthly: monthly,
        totalInterest: totalInterest,
        totalCost: totalCost,
        months: n.round(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Loan calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _principalCtrl,
            decoration: const InputDecoration(
              labelText: 'Loan amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateCtrl,
            decoration: const InputDecoration(
              labelText: 'Annual interest rate',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _termCtrl,
            decoration: const InputDecoration(
              labelText: 'Term',
              suffixText: 'years',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Enter loan amount, interest rate, and term to see your monthly payment.',
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
  final _LoanResult result;
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
            Text('Monthly payment', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              fmt.format(result.monthly),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Total interest paid', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.totalInterest),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Total cost of loan', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.totalCost),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Number of payments', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text('${result.months}',
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
              'Uses the standard amortization formula: '
              'payment = P × (r(1+r)^n) / ((1+r)^n − 1), where P is the '
              'principal, r is the monthly interest rate, and n is the '
              'number of monthly payments.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Each payment covers interest on the remaining balance plus '
              'a portion of principal. Early payments are mostly interest; '
              'later payments are mostly principal.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanResult {
  const _LoanResult({
    required this.monthly,
    required this.totalInterest,
    required this.totalCost,
    required this.months,
  });

  final double monthly;
  final double totalInterest;
  final double totalCost;
  final int months;
}
