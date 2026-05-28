import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/relationship_order_controller.dart';
import 'relationship_modules.dart';

class RearrangeRelationshipPage extends StatefulWidget {
  const RearrangeRelationshipPage({super.key});

  @override
  State<RearrangeRelationshipPage> createState() =>
      _RearrangeRelationshipPageState();
}

class _RearrangeRelationshipPageState
    extends State<RearrangeRelationshipPage> {
  late List<RelationshipSubmodule> _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        List.from(Get.find<RelationshipOrderController>().submodules);
  }

  Future<void> _save() async {
    try {
      final c = Get.find<RelationshipOrderController>();
      await c.setOrder(_draft.map((s) => s.id).toList());
      Get.back();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save order')),
      );
    }
  }

  Future<void> _reset() async {
    final c = Get.find<RelationshipOrderController>();
    await c.resetToDefault();
    if (!mounted) return;
    setState(() => _draft = List.from(c.submodules));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rearrange'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _reset();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset to defaults')),
            ],
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _draft.length,
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final item = _draft.removeAt(oldIndex);
            _draft.insert(newIndex.clamp(0, _draft.length), item);
          });
        },
        itemBuilder: (_, i) {
          final s = _draft[i];
          return Card(
            key: ValueKey(s.id),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                child: Icon(s.icon),
              ),
              title: Text(s.label),
              subtitle: Text(s.subtitle),
              trailing: const Icon(Icons.drag_handle),
            ),
          );
        },
      ),
    );
  }
}
