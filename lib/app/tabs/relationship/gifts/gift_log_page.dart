import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/gift_controller.dart';
import '../../../../database/models.dart';

class GiftLogPage extends StatelessWidget {
  const GiftLogPage({super.key});

  static const _suggestedOccasions = [
    'Birthday',
    'Anniversary',
    'Christmas',
    'Valentine\'s',
    'Just because',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(GiftController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Gifts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGiftSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final currentTab = c.tab.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<GiftTab>(
                segments: const [
                  ButtonSegment(value: GiftTab.ideas, label: Text('Ideas')),
                  ButtonSegment(value: GiftTab.given, label: Text('Given')),
                ],
                selected: {currentTab},
                onSelectionChanged: (s) => c.tab.value = s.first,
              ),
            ),
            Expanded(
              child: currentTab == GiftTab.ideas
                  ? _buildList(c.ideas, c, isIdeas: true)
                  : _buildList(c.given, c, isIdeas: false),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildList(List<GiftEntry> list, GiftController c,
      {required bool isIdeas}) {
    if (list.isEmpty) {
      return Center(
        child: Text(isIdeas
            ? 'No gift ideas yet. Tap + to add one.'
            : 'No gifts given yet.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _GiftTile(entry: list[i], isIdea: isIdeas),
    );
  }
}

void _showGiftSheet(BuildContext context, GiftController c,
    {GiftEntry? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _GiftSheetContent(controller: c, existing: existing),
  );
}

class _GiftSheetContent extends StatefulWidget {
  const _GiftSheetContent({required this.controller, this.existing});
  final GiftController controller;
  final GiftEntry? existing;

  @override
  State<_GiftSheetContent> createState() => _GiftSheetContentState();
}

class _GiftSheetContentState extends State<_GiftSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _occasionCtrl;
  late final TextEditingController _priceCtrl;
  late String _status;
  DateTime? _givenAt;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _occasionCtrl = TextEditingController(text: e?.occasion ?? '');
    _priceCtrl = TextEditingController(
        text: e?.price != null ? e!.price.toString() : '');
    _status = e?.status ?? 'idea';
    _givenAt = e?.givenAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _occasionCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(_isEdit ? 'Edit gift' : 'New gift',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _occasionCtrl,
              decoration: const InputDecoration(
                labelText: 'Occasion',
                hintText: 'e.g. Birthday, Anniversary',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: GiftLogPage._suggestedOccasions
                  .map((o) => ActionChip(
                        label: Text(o),
                        onPressed: () => _occasionCtrl.text = o,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price (optional)',
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'idea', label: Text('Idea')),
                ButtonSegment(value: 'given', label: Text('Given')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() {
                _status = s.first;
                if (_status == 'given' && _givenAt == null) {
                  _givenAt = DateTime.now();
                }
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (_isEdit) {
      widget.controller.updateGift(
        widget.existing!,
        title: _titleCtrl.text,
        notes: _notesCtrl.text,
        status: _status,
        occasion: _occasionCtrl.text,
        price: price,
        givenAt: _status == 'given' ? (_givenAt ?? DateTime.now()) : null,
      );
    } else {
      widget.controller.add(
        title: _titleCtrl.text,
        notes: _notesCtrl.text,
        status: _status,
        occasion: _occasionCtrl.text,
        price: price,
        givenAt: _status == 'given' ? (_givenAt ?? DateTime.now()) : null,
      );
    }
    Navigator.pop(context);
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.entry, required this.isIdea});
  final GiftEntry entry;
  final bool isIdea;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<GiftController>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(entry),
      child: ListTile(
        onTap: () => _showGiftSheet(context, c, existing: entry),
        leading: isIdea
            ? IconButton(
                tooltip: 'Mark as given',
                icon: const Icon(Icons.card_giftcard_outlined),
                onPressed: () => c.markGiven(entry),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
        title: Text(entry.title),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (entry.occasion != null && entry.occasion!.isNotEmpty) {
      parts.add(entry.occasion!);
    }
    if (entry.price != null) {
      parts.add('\$${entry.price!.toStringAsFixed(2)}');
    }
    if (entry.status == 'given' && entry.givenAt != null) {
      parts.add('Given ${DateFormat.yMMMd().format(entry.givenAt!)}');
    }
    if (entry.notes != null && entry.notes!.isNotEmpty) {
      parts.add(entry.notes!);
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
