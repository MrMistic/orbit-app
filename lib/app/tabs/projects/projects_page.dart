import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class ProjectsController extends GetxController {
  final _box = ObjectBox.instance.projectBox;

  final projects = <Project>[].obs;

  static const _statusOrder = ['active', 'paused', 'completed', 'abandoned'];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _box.getAll();
    all.sort((a, b) {
      final ai = _statusOrder.indexOf(a.status);
      final bi = _statusOrder.indexOf(b.status);
      if (ai != bi) return ai.compareTo(bi);
      return b.createdAt.compareTo(a.createdAt);
    });
    projects.assignAll(all);
  }

  void add({required String name, String? description, DateTime? deadline}) {
    _box.put(Project(name: name, description: description, deadline: deadline));
    _load();
  }

  void updateProject(Project project) {
    _box.put(project);
    _load();
  }

  void remove(Project project) {
    _box.remove(project.id);
    _load();
  }

  Project? findById(int id) {
    try {
      return _box.get(id);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProjectsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.projects;
        if (list.isEmpty) {
          return const Center(
              child: Text('No projects yet. Tap + to add one.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _ProjectTile(project: list[i], controller: c),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.controller});
  final Project project;
  final ProjectsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = _parseTasks(project.tasks);
    final done = tasks.where((t) => t.checked).length;
    final total = tasks.length;

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ProjectDetailPage(
              projectId: project.id, controller: controller),
        ),
      ),
      title: Text(project.name),
      subtitle: Text(
        [
          project.status[0].toUpperCase() + project.status.substring(1),
          if (total > 0) '$done/$total tasks',
          if (project.deadline != null)
            'Due ${DateFormat.yMMMd().format(project.deadline!)}',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        _statusIcon(project.status),
        color: _statusColor(project.status, theme),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle_outline;
      case 'paused':
        return Icons.pause_circle_outline;
      case 'completed':
        return Icons.check_circle_outline;
      case 'abandoned':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'active':
        return theme.colorScheme.primary;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'abandoned':
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurface;
    }
  }
}

// ---------------------------------------------------------------------------
// Detail page (task checklist)
// ---------------------------------------------------------------------------

class _ProjectDetailPage extends StatefulWidget {
  const _ProjectDetailPage(
      {required this.projectId, required this.controller});
  final int projectId;
  final ProjectsController controller;

  @override
  State<_ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<_ProjectDetailPage> {
  final _addTaskCtrl = TextEditingController();

  @override
  void dispose() {
    _addTaskCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);

    final project = c.findById(widget.projectId);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Project not found.')),
      );
    }

    final tasks = _parseTasks(project.tasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                _showProjectSheet(context, c, existing: project),
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              c.remove(project);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (project.description != null &&
              project.description!.isNotEmpty) ...[
            Text(project.description!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
          ],
          // Status dropdown
          Row(
            children: [
              Text('Status: ', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: project.status,
                items: const [
                  DropdownMenuItem(
                      value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                      value: 'paused', child: Text('Paused')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(
                      value: 'abandoned', child: Text('Abandoned')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    project.status = v;
                    c.updateProject(project);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          if (project.deadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Deadline: ${DateFormat.yMMMd().format(project.deadline!)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          Text('Tasks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...tasks.asMap().entries.map((e) => _TaskItem(
                item: e.value,
                onToggle: () =>
                    _toggleTask(c, project, tasks, e.key),
                onDelete: () =>
                    _deleteTask(c, project, tasks, e.key),
              )),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addTaskCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add task',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) =>
                        _addTask(c, project, tasks),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTask(c, project, tasks),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addTask(
      ProjectsController c, Project project, List<_TaskEntry> tasks) {
    final text = _addTaskCtrl.text.trim();
    if (text.isEmpty) return;
    tasks.add(_TaskEntry(name: text, checked: false));
    project.tasks = _serializeTasks(tasks);
    c.updateProject(project);
    _addTaskCtrl.clear();
    setState(() {});
  }

  void _toggleTask(
      ProjectsController c, Project project, List<_TaskEntry> tasks, int i) {
    tasks[i] = _TaskEntry(name: tasks[i].name, checked: !tasks[i].checked);
    project.tasks = _serializeTasks(tasks);
    c.updateProject(project);
    setState(() {});
  }

  void _deleteTask(
      ProjectsController c, Project project, List<_TaskEntry> tasks, int i) {
    tasks.removeAt(i);
    project.tasks = _serializeTasks(tasks);
    c.updateProject(project);
    setState(() {});
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem(
      {required this.item, required this.onToggle, required this.onDelete});
  final _TaskEntry item;
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TaskEntry {
  const _TaskEntry({required this.name, required this.checked});
  final String name;
  final bool checked;
}

List<_TaskEntry> _parseTasks(String raw) {
  if (raw.trim().isEmpty) return [];
  return raw.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
    if (l.startsWith('[x] ')) {
      return _TaskEntry(name: l.substring(4), checked: true);
    }
    return _TaskEntry(name: l, checked: false);
  }).toList();
}

String _serializeTasks(List<_TaskEntry> tasks) {
  return tasks
      .map((t) => t.checked ? '[x] ${t.name}' : t.name)
      .join('\n');
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showProjectSheet(BuildContext context, ProjectsController c,
    {Project? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _ProjectSheetContent(controller: c, existing: existing),
  );
}

class _ProjectSheetContent extends StatefulWidget {
  const _ProjectSheetContent({required this.controller, this.existing});
  final ProjectsController controller;
  final Project? existing;

  @override
  State<_ProjectSheetContent> createState() => _ProjectSheetContentState();
}

class _ProjectSheetContentState extends State<_ProjectSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _deadline;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _deadline = widget.existing?.deadline;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
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
            Text(_isEdit ? 'Edit project' : 'New project',
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
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_deadline != null
                  ? 'Deadline: ${DateFormat.yMMMd().format(_deadline!)}'
                  : 'Set deadline (optional)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                  ),
                  if (_deadline != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                ],
              ),
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
    if (_isEdit) {
      final project = widget.existing!;
      project.name = name;
      project.description =
          _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null;
      project.deadline = _deadline;
      widget.controller.updateProject(project);
    } else {
      widget.controller.add(
        name: name,
        description:
            _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        deadline: _deadline,
      );
    }
    Navigator.pop(context);
  }
}
