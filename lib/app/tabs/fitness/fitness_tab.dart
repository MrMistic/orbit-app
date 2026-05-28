import 'package:flutter/material.dart';

import 'fitness_modules.dart';

class FitnessTab extends StatelessWidget {
  const FitnessTab({super.key});

  @override
  Widget build(BuildContext context) {
    final subs = FitnessRegistry.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Fitness')),
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
