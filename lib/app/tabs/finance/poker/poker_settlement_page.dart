import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single payment instruction: from → to, amount.
class Transfer {
  const Transfer({required this.from, required this.to, required this.amount});
  final String from;
  final String to;
  final double amount;
}

/// Greedy debt simplification algorithm.
/// Computes minimum transfers to settle all balances.
/// Approach: match max creditor with max debtor repeatedly.
List<Transfer> computeSettlement(Map<String, double> balances) {
  // Filter out zero balances.
  final creditors = <String, double>{}; // positive = owed money
  final debtors = <String, double>{};   // negative = owes money

  for (final entry in balances.entries) {
    if (entry.value > 0.005) {
      creditors[entry.key] = entry.value;
    } else if (entry.value < -0.005) {
      debtors[entry.key] = entry.value.abs();
    }
  }

  final transfers = <Transfer>[];

  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    // Find max creditor and max debtor.
    final maxCreditor = creditors.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final maxDebtor = debtors.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final amount = maxCreditor.value < maxDebtor.value ? maxCreditor.value : maxDebtor.value;

    transfers.add(Transfer(from: maxDebtor.key, to: maxCreditor.key, amount: amount));

    // Update balances.
    creditors[maxCreditor.key] = maxCreditor.value - amount;
    debtors[maxDebtor.key] = maxDebtor.value - amount;

    if (creditors[maxCreditor.key]! < 0.005) creditors.remove(maxCreditor.key);
    if (debtors[maxDebtor.key]! < 0.005) debtors.remove(maxDebtor.key);
  }

  return transfers;
}

class PokerSettlementPage extends StatefulWidget {
  const PokerSettlementPage({super.key});

  @override
  State<PokerSettlementPage> createState() => _PokerSettlementPageState();
}

class _PokerSettlementPageState extends State<PokerSettlementPage> {
  final _players = <_PlayerEntry>[];
  List<Transfer>? _result;

  void _addPlayer() {
    setState(() {
      _players.add(_PlayerEntry(
        nameCtrl: TextEditingController(),
        amountCtrl: TextEditingController(),
      ));
    });
  }

  void _removePlayer(int index) {
    setState(() {
      _players[index].nameCtrl.dispose();
      _players[index].amountCtrl.dispose();
      _players.removeAt(index);
      _result = null;
    });
  }

  void _calculate() {
    final balances = <String, double>{};
    for (final p in _players) {
      final name = p.nameCtrl.text.trim();
      final amount = double.tryParse(p.amountCtrl.text.trim());
      if (name.isEmpty || amount == null) continue;
      // Positive = won (net gain), negative = lost (net loss)
      balances[name] = amount;
    }
    if (balances.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players with amounts.')),
      );
      return;
    }
    // Verify zero-sum (net gains should roughly equal net losses).
    final sum = balances.values.fold<double>(0, (a, b) => a + b);
    if (sum.abs() > 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Amounts don\'t balance. Net is ${sum >= 0 ? '+' : ''}\$${sum.toStringAsFixed(2)}.'
          ' Gains and losses should sum to \$0.',
        )),
      );
      return;
    }
    setState(() => _result = computeSettlement(balances));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Poker settlement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlayer,
        icon: const Icon(Icons.person_add),
        label: const Text('Player'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Enter each player\'s net gain or loss:',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Positive = won money. Negative = lost money.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 12),
          ..._players.asMap().entries.map((e) => _PlayerRow(
            entry: e.value,
            index: e.key,
            onRemove: () => _removePlayer(e.key),
          )),
          if (_players.length >= 2) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate settlements'),
            ),
          ],
          if (_result != null) ...[
            const Divider(height: 32),
            Text('Minimum transfers (${_result!.length}):',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._result!.map((t) => Card(
              child: ListTile(
                leading: const Icon(Icons.arrow_forward, color: Colors.green),
                title: Text('${t.from} → ${t.to}'),
                trailing: Text(
                  '\$${t.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )),
          ],
          if (_players.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text('Tap "Player" to add people to this session.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.entry, required this.index, required this.onRemove});
  final _PlayerEntry entry;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: entry.nameCtrl,
              decoration: InputDecoration(
                labelText: 'Player ${index + 1}',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.amountCtrl,
              decoration: const InputDecoration(
                labelText: '+/- \$',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _PlayerEntry {
  _PlayerEntry({required this.nameCtrl, required this.amountCtrl});
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
}
