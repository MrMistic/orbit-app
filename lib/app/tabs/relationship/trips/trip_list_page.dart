import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/trip_controller.dart';
import '../../../../database/models.dart';
import 'trip_detail_page.dart';

class TripListPage extends StatelessWidget {
  const TripListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(TripController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip planner')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTripSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.trips;
        if (list.isEmpty) {
          return const Center(
            child: Text('No trips yet. Tap + to plan one.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _TripTile(trip: list[i]),
        );
      }),
    );
  }
}

void _showTripSheet(BuildContext context, TripController c,
    {Trip? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TripSheetContent(controller: c, existing: existing),
  );
}

class _TripSheetContent extends StatefulWidget {
  const _TripSheetContent({required this.controller, this.existing});
  final TripController controller;
  final Trip? existing;

  @override
  State<_TripSheetContent> createState() => _TripSheetContentState();
}

class _TripSheetContentState extends State<_TripSheetContent> {
  late final TextEditingController _destCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _destCtrl = TextEditingController(text: e?.destination ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit trip' : 'New trip',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _destCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'e.g. Paris, Yosemite, Tokyo',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_startDate != null
                        ? fmt.format(_startDate!)
                        : 'Start date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                        _endDate != null ? fmt.format(_endDate!) : 'End date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_isEdit) {
                  widget.controller.updateTrip(
                    widget.existing!,
                    destination: _destCtrl.text,
                    notes: _notesCtrl.text,
                    startDate: _startDate,
                    endDate: _endDate,
                  );
                } else {
                  widget.controller.add(
                    destination: _destCtrl.text,
                    notes: _notesCtrl.text,
                    startDate: _startDate,
                    endDate: _endDate,
                  );
                }
                Navigator.pop(context);
              },
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TripController>();
    final theme = Theme.of(context);
    final fmt = DateFormat.MMMd();

    String? dateLabel;
    if (trip.startDate != null && trip.endDate != null) {
      dateLabel = '${fmt.format(trip.startDate!)} – ${fmt.format(trip.endDate!)}';
    } else if (trip.startDate != null) {
      dateLabel = fmt.format(trip.startDate!);
    }

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(trip),
      child: ListTile(
        onTap: () => Get.to(() => TripDetailPage(tripId: trip.id)),
        onLongPress: () => _showTripSheet(context, c, existing: trip),
        leading: const Icon(Icons.flight_takeoff_outlined),
        title: Text(trip.destination),
        subtitle: dateLabel != null
            ? Text(dateLabel, style: theme.textTheme.bodySmall)
            : null,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
