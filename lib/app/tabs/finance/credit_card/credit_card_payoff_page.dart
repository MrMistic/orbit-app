import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../database/models.dart';
import '../../../../database/object_box.dart';

/// Credit card payoff calculator. Simulates monthly payments to compute
/// how long it takes to pay off the balance and total interest paid.
class CreditCardPayoffPage extends StatefulWidget {
  const CreditCardPayoffPage({super.key});

  @override
  State<CreditCardPayoffPage> createState() => _CreditCardPayoffPageState();
}

class _CreditCardPayoffPageState extends State<CreditCardPayoffPage> {
  final _balanceCtrl = TextEditingController();
  final _aprCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _annualFeeCtrl = TextEditingController();

  /// Currently selected saved card, if any. When set, APR and fee come from it.
  RewardsCard? _selectedCard;

  static const int _maxMonths = 600;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _aprCtrl.dispose();
    _paymentCtrl.dispose();
    _annualFeeCtrl.dispose();
    super.dispose();
  }

  void _selectCard(RewardsCard? card) {
    setState(() {
      _selectedCard = card;
      if (card != null) {
        if (card.apr != null) {
          _aprCtrl.text = card.apr!.toString();
        }
        _annualFeeCtrl.text =
            card.annualFee > 0 ? card.annualFee.toString() : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.simpleCurrency();

    final balance = double.tryParse(_balanceCtrl.text.trim());
    final apr = double.tryParse(_aprCtrl.text.trim());
    final payment = double.tryParse(_paymentCtrl.text.trim());
    final annualFee = double.tryParse(_annualFeeCtrl.text.trim()) ?? 0;

    _PayoffResult? result;
    bool insufficientPayment = false;
    double? firstMonthInterest;

    if (balance != null &&
        balance > 0 &&
        apr != null &&
        apr >= 0 &&
        payment != null &&
        payment > 0) {
      final monthlyRate = (apr / 100) / 12;
      firstMonthInterest = balance * monthlyRate;
      if (payment <= firstMonthInterest && monthlyRate > 0) {
        insufficientPayment = true;
      } else {
        var remaining = balance;
        var months = 0;
        var totalInterest = 0.0;
        var totalPaid = 0.0;
        var totalFees = 0.0;
        while (remaining > 0 && months < _maxMonths) {
          final interest = remaining * monthlyRate;
          // Apply annual fee at the start of every 12-month period.
          if (annualFee > 0 && months > 0 && months % 12 == 0) {
            remaining += annualFee;
            totalFees += annualFee;
          }
          var principal = payment - interest;
          if (principal <= 0) {
            insufficientPayment = true;
            break;
          }
          if (principal > remaining) {
            principal = remaining;
          }
          final actualPayment = principal + interest;
          totalInterest += interest;
          totalPaid += actualPayment;
          remaining -= principal;
          months++;
        }
        if (!insufficientPayment) {
          result = _PayoffResult(
            months: months,
            totalInterest: totalInterest,
            totalFees: totalFees,
            totalPaid: totalPaid,
            cappedAtMax: months >= _maxMonths && remaining > 0,
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Credit card payoff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _CardPicker(
            selected: _selectedCard,
            onSelected: _selectCard,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            decoration: const InputDecoration(
              labelText: 'Current balance',
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
            controller: _aprCtrl,
            decoration: const InputDecoration(
              labelText: 'APR',
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
            controller: _paymentCtrl,
            decoration: const InputDecoration(
              labelText: 'Monthly payment',
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
            controller: _annualFeeCtrl,
            decoration: const InputDecoration(
              labelText: 'Annual fee (optional)',
              prefixText: '\$ ',
              helperText: 'Charged once per year',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (insufficientPayment)
            _WarningCard(
              firstMonthInterest: firstMonthInterest,
              fmt: fmt,
            )
          else if (result == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Enter your balance, APR, and monthly payment to see how long until payoff.',
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

String _formatMonths(int months) {
  final years = months ~/ 12;
  final rem = months % 12;
  if (years == 0) return '$rem ${rem == 1 ? 'month' : 'months'}';
  if (rem == 0) return '$years ${years == 1 ? 'year' : 'years'}';
  return '$years ${years == 1 ? 'year' : 'years'} '
      '$rem ${rem == 1 ? 'month' : 'months'}';
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.fmt});
  final _PayoffResult result;
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
            Text('Time to payoff', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              _formatMonths(result.months),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (result.cappedAtMax) ...[
              const SizedBox(height: 4),
              Text(
                'Capped at 50 years for safety. Try a higher payment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Text('Total interest paid', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.totalInterest),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            if (result.totalFees > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Total annual fees', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text(fmt.format(result.totalFees),
                      style: theme.textTheme.titleSmall),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Total amount paid', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(fmt.format(result.totalPaid),
                    style: theme.textTheme.titleSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.firstMonthInterest, required this.fmt});
  final double? firstMonthInterest;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text('Payment too low',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your monthly payment is below the first month\'s interest charge'
              '${firstMonthInterest != null ? ' (${fmt.format(firstMonthInterest)})' : ''}. '
              'The balance will grow each month and never be paid off. '
              'Increase your payment above the monthly interest to make progress.',
              style: theme.textTheme.bodySmall,
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
              'Each month, interest accrues on the remaining balance at '
              'APR / 12. Your payment first covers that interest; the rest '
              'reduces the principal. The simulation continues until the '
              'balance reaches zero.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Pay more than the minimum to slash interest and time to '
              'payoff. Even small extra payments compound quickly.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoffResult {
  const _PayoffResult({
    required this.months,
    required this.totalInterest,
    required this.totalFees,
    required this.totalPaid,
    required this.cappedAtMax,
  });

  final int months;
  final double totalInterest;
  final double totalFees;
  final double totalPaid;
  final bool cappedAtMax;
}

class _CardPicker extends StatelessWidget {
  const _CardPicker({required this.selected, required this.onSelected});
  final RewardsCard? selected;
  final ValueChanged<RewardsCard?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ObjectBox.instance.rewardsCardBox.getAll()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (cards.isEmpty) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.credit_card, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<RewardsCard?>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Use saved card (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<RewardsCard?>(
                    value: null,
                    child: Text('Manual entry'),
                  ),
                  for (final c in cards)
                    DropdownMenuItem<RewardsCard?>(
                      value: c,
                      child: Text(c.name),
                    ),
                ],
                onChanged: onSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
