import 'package:flutter/material.dart';

import 'finance_modules.dart';

class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final subs = FinanceRegistry.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      body: ListView.builder(
        itemCount: subs.length,
        itemBuilder: (ctx, i) {
          final s = subs[i];
          return ListTile(
            leading: Icon(s.icon),
            title: Text(s.label),
            subtitle: Text(s.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(ctx).push(
                MaterialPageRoute(builder: s.pageBuilder),
              );
            },
          );
        },
      ),
    );
  }
}
