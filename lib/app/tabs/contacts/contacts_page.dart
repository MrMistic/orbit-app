import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class ContactsController extends GetxController {
  final _box = ObjectBox.instance.crmContactBox;

  final contacts = <CrmContact>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    // Sort: overdue first, then by days since contact descending
    all.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      final aDays = a.daysSinceContact ?? 99999;
      final bDays = b.daysSinceContact ?? 99999;
      return bDays.compareTo(aDays);
    });
    contacts.assignAll(all);
  }

  void add({
    required String name,
    String? relationship,
    String? phone,
    String? email,
    String? notes,
    int? reachOutDays,
  }) {
    _box.put(CrmContact(
      name: name,
      relationship: relationship,
      phone: phone,
      email: email,
      notes: notes,
      reachOutDays: reachOutDays,
    ));
    _load();
  }

  void updateContact(CrmContact contact) {
    _box.put(contact);
    _load();
  }

  void markContacted(CrmContact contact) {
    contact.lastContactedAt = DateTime.now();
    _box.put(contact);
    _load();
  }

  void remove(CrmContact contact) {
    _box.remove(contact.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ContactsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.contacts;
        if (list.isEmpty) {
          return const Center(child: Text('No contacts yet. Tap + to add.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _ContactTile(contact: list[i], controller: c),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.controller});
  final CrmContact contact;
  final ContactsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = contact.daysSinceContact;
    final overdue = contact.isOverdue;

    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.remove(contact),
      child: ListTile(
        onTap: () =>
            _showContactSheet(context, controller, existing: contact),
        title: Row(
          children: [
            Expanded(child: Text(contact.name)),
            if (overdue)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Overdue',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (contact.relationship != null &&
                contact.relationship!.isNotEmpty)
              contact.relationship!,
            if (days != null) '$days days ago' else 'Never contacted',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.touch_app_outlined),
          tooltip: 'Mark contacted',
          onPressed: () => controller.markContacted(contact),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showContactSheet(BuildContext context, ContactsController c,
    {CrmContact? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _ContactSheetContent(controller: c, existing: existing),
  );
}

class _ContactSheetContent extends StatefulWidget {
  const _ContactSheetContent({required this.controller, this.existing});
  final ContactsController controller;
  final CrmContact? existing;

  @override
  State<_ContactSheetContent> createState() => _ContactSheetContentState();
}

class _ContactSheetContentState extends State<_ContactSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _relCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _freqCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _relCtrl =
        TextEditingController(text: widget.existing?.relationship ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _freqCtrl = TextEditingController(
        text: widget.existing?.reachOutDays?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _freqCtrl.dispose();
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
            Text(_isEdit ? 'Edit contact' : 'New contact',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _relCtrl,
              decoration: const InputDecoration(
                  labelText: 'Relationship (optional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              decoration:
                  const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _freqCtrl,
              decoration: const InputDecoration(
                labelText: 'Reach-out frequency (days)',
                hintText: 'e.g. 14',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final freq = int.tryParse(_freqCtrl.text.trim());

    if (_isEdit) {
      final contact = widget.existing!;
      contact.name = name;
      contact.relationship =
          _relCtrl.text.trim().isNotEmpty ? _relCtrl.text.trim() : null;
      contact.phone =
          _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null;
      contact.email =
          _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null;
      contact.notes =
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      contact.reachOutDays = freq;
      widget.controller.updateContact(contact);
    } else {
      widget.controller.add(
        name: name,
        relationship:
            _relCtrl.text.trim().isNotEmpty ? _relCtrl.text.trim() : null,
        phone:
            _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        email:
            _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        reachOutDays: freq,
      );
    }
    Navigator.pop(context);
  }
}
