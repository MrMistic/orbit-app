import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class NotesController extends GetxController {
  final _box = ObjectBox.instance.noteBox;
  final notes = <Note>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    // Pinned first, then by updatedAt descending.
    all.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    notes.assignAll(all);
  }

  void add({required String title, String body = '', String? category}) {
    if (title.trim().isEmpty) return;
    _box.put(Note(title: title.trim(), body: body, category: category));
    _load();
  }

  void save(Note note) {
    note.updatedAt = DateTime.now();
    _box.put(note);
    _load();
  }

  void togglePin(Note note) {
    note.pinned = !note.pinned;
    note.updatedAt = DateTime.now();
    _box.put(note);
    _load();
  }

  void remove(Note note) {
    _box.remove(note.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(NotesController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, c, null),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (c.notes.isEmpty) {
          return const Center(
            child: Text('No notes yet. Tap + to create one.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: c.notes.length,
          itemBuilder: (ctx, i) {
            final note = c.notes[i];
            final preview = note.body.length > 80
                ? '${note.body.substring(0, 80)}…'
                : note.body;
            return ListTile(
              leading: note.pinned
                  ? const Icon(Icons.push_pin, size: 20)
                  : null,
              title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                preview.isEmpty
                    ? DateFormat.yMMMd().format(note.updatedAt)
                    : preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                DateFormat.MMMd().format(note.updatedAt),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              onTap: () => _openEditor(context, c, note),
              onLongPress: () => _showOptions(context, c, note),
            );
          },
        );
      }),
    );
  }

  void _openEditor(BuildContext context, NotesController c, Note? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditorPage(controller: c, existing: existing),
      ),
    );
  }

  void _showOptions(BuildContext context, NotesController c, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(note.pinned ? 'Unpin' : 'Pin to top'),
              onTap: () { Navigator.pop(ctx); c.togglePin(note); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); c.remove(note); },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

class _NoteEditorPage extends StatefulWidget {
  const _NoteEditorPage({required this.controller, this.existing});
  final NotesController controller;
  final Note? existing;

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late final TextEditingController _titleC;
  late final TextEditingController _bodyC;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.existing?.title ?? '');
    _bodyC = TextEditingController(text: widget.existing?.body ?? '');
    _titleC.addListener(_markDirty);
    _bodyC.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _save();
    _titleC.dispose();
    _bodyC.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleC.text.trim();
    if (title.isEmpty) return;
    if (widget.existing != null) {
      widget.existing!.title = title;
      widget.existing!.body = _bodyC.text;
      widget.controller.save(widget.existing!);
    } else if (_dirty) {
      widget.controller.add(title: title, body: _bodyC.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New note' : 'Edit note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleC,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.titleLarge,
              textCapitalization: TextCapitalization.sentences,
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _bodyC,
                decoration: const InputDecoration(
                  hintText: 'Start writing…',
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
