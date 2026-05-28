import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modules.dart';
import '../../controllers/module_order_controller.dart';

class RearrangeModulesPage extends StatefulWidget {
  const RearrangeModulesPage({super.key});

  @override
  State<RearrangeModulesPage> createState() => _RearrangeModulesPageState();
}

class _RearrangeModulesPageState extends State<RearrangeModulesPage> {
  late List<AppModule> _draft;

  @override
  void initState() {
    super.initState();
    _draft = List.from(Get.find<ModuleOrderController>().orderedModules);
  }

  Future<void> _save() async {
    final c = Get.find<ModuleOrderController>();
    await c.setOrder(_draft.map((m) => m.id).toList());
    Get.back();
  }

  Future<void> _resetDefaults() async {
    final c = Get.find<ModuleOrderController>();
    await c.resetToDefault();
    if (!mounted) return;
    setState(() => _draft = List.from(c.orderedModules));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const homeCount = ModuleOrderController.homeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rearrange modules'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _resetDefaults();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reset',
                child: Text('Reset to defaults'),
              ),
            ],
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'The first three modules appear in the bottom navigation. The rest live in the More tab. Drag to reorder.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _draft.length + 1, // +1 for the divider header
              onReorderItem: (oldIndex, newIndex) {
                // Skip moves that involve the divider (index = homeCount).
                if (oldIndex == homeCount || newIndex == homeCount) return;

                // Adjust indices to ignore the divider entry.
                final adjOld = oldIndex < homeCount ? oldIndex : oldIndex - 1;
                final adjNew = newIndex < homeCount ? newIndex : newIndex - 1;

                setState(() {
                  final item = _draft.removeAt(adjOld);
                  _draft.insert(adjNew.clamp(0, _draft.length), item);
                });
              },
              itemBuilder: (context, index) {
                if (index == homeCount) {
                  return _SectionDivider(
                    key: const ValueKey('__divider__'),
                    label: 'More tab',
                    icon: Icons.apps,
                  );
                }
                final mod = index < homeCount
                    ? _draft[index]
                    : _draft[index - 1];
                final inHome = index < homeCount;

                return _ModuleTile(
                  key: ValueKey(mod.id),
                  module: mod,
                  position: inHome ? index + 1 : null,
                  inHome: inHome,
                );
              },
              header: _SectionHeader(
                label: 'Home tabs (bottom navigation)',
                icon: Icons.home_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              )),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(color: theme.colorScheme.outlineVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    super.key,
    required this.module,
    required this.position,
    required this.inHome,
  });

  final AppModule module;
  final int? position;
  final bool inHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: inHome
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: inHome
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: inHome
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: Icon(module.icon),
        ),
        title: Row(
          children: [
            Expanded(child: Text(module.label)),
            if (position != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Home $position',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(module.subtitle),
        trailing: const Icon(Icons.drag_handle),
      ),
    );
  }
}
