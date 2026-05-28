import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/relationship_order_controller.dart';
import 'relationship/rearrange_relationship_page.dart';

class RelationshipTab extends StatelessWidget {
  const RelationshipTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RelationshipOrderController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relationship'),
        actions: [
          IconButton(
            tooltip: 'Rearrange',
            icon: const Icon(Icons.tune),
            onPressed: () => Get.to(() => const RearrangeRelationshipPage()),
          ),
        ],
      ),
      body: Obx(() {
        final subs = c.submodules;
        return ListView.builder(
          itemCount: subs.length,
          itemBuilder: (context, i) {
            final s = subs[i];
            return ListTile(
              leading: Icon(s.icon),
              title: Text(s.label),
              subtitle: Text(s.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => s.pageBuilder(context)),
            );
          },
        );
      }),
    );
  }
}
