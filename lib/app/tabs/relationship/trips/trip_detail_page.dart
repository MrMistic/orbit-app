import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/trip_controller.dart';
import '../../../../database/models.dart';

class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final int tripId;

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final _addItemCtrl = TextEditingController();

  @override
  void dispose() {
    _addItemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TripController>();
    final theme = Theme.of(context);

    return Obx(() {
      final _ = c.trips; // trigger rebuild
      final trip = c.findById(widget.tripId);
      if (trip == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Trip not found.')),
        );
      }

      final items = _parsePackingList(trip.packingList);
      final fmt = DateFormat.yMMMd();

      return Scaffold(
        appBar: AppBar(
          title: Text(trip.destination),
          actions: [
            IconButton(
              tooltip: 'Delete trip',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await c.remove(trip);
                Get.back();
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (trip.startDate != null || trip.endDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      [
                        if (trip.startDate != null) fmt.format(trip.startDate!),
                        if (trip.endDate != null) fmt.format(trip.endDate!),
                      ].join(' – '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            if (trip.notes != null && trip.notes!.isNotEmpty) ...[
              Text(trip.notes!, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
            ],
            Text('Packing list', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((e) => _PackingItem(
                  index: e.key,
                  item: e.value,
                  onToggle: () => _toggleItem(c, trip, items, e.key),
                  onDelete: () => _deleteItem(c, trip, items, e.key),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addItemCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add item',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addItem(c, trip, items),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addItem(c, trip, items),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _addItem(TripController c, Trip trip, List<_PackItem> items) {
    final text = _addItemCtrl.text.trim();
    if (text.isEmpty) return;
    items.add(_PackItem(name: text, checked: false));
    c.updatePackingList(trip, _serializePackingList(items));
    _addItemCtrl.clear();
  }

  void _toggleItem(
      TripController c, Trip trip, List<_PackItem> items, int index) {
    items[index] = _PackItem(
      name: items[index].name,
      checked: !items[index].checked,
    );
    c.updatePackingList(trip, _serializePackingList(items));
  }

  void _deleteItem(
      TripController c, Trip trip, List<_PackItem> items, int index) {
    items.removeAt(index);
    c.updatePackingList(trip, _serializePackingList(items));
  }

  List<_PackItem> _parsePackingList(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      if (l.startsWith('[x] ')) {
        return _PackItem(name: l.substring(4), checked: true);
      }
      return _PackItem(name: l, checked: false);
    }).toList();
  }

  String _serializePackingList(List<_PackItem> items) {
    return items
        .map((i) => i.checked ? '[x] ${i.name}' : i.name)
        .join('\n');
  }
}

class _PackItem {
  const _PackItem({required this.name, required this.checked});
  final String name;
  final bool checked;
}

class _PackingItem extends StatelessWidget {
  const _PackingItem({
    required this.index,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final int index;
  final _PackItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.checked,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.checked ? TextDecoration.lineThrough : null,
          color: item.checked ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: onDelete,
      ),
    );
  }
}
