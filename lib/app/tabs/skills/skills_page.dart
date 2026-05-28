import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SkillsController extends GetxController {
  final _skillBox = ObjectBox.instance.skillBox;
  final _sessionBox = ObjectBox.instance.practiceSessionBox;

  final skills = <Skill>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final all = _skillBox.getAll();
    all.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    skills.assignAll(all);
  }

  void addSkill({required String name, String? category, String? notes}) {
    _skillBox.put(Skill(name: name, category: category, notes: notes));
    _load();
  }

  void updateSkill(Skill skill) {
    _skillBox.put(skill);
    _load();
  }

  void removeSkill(Skill skill) {
    _skillBox.remove(skill.id);
    _load();
  }

  void logSession(Skill skill, {required int minutes, String? notes}) {
    _sessionBox.put(PracticeSession(
      skillName: skill.name,
      durationMinutes: minutes,
      notes: notes,
    ));
    skill.totalMinutes += minutes;
    skill.lastPracticedAt = DateTime.now();
    _skillBox.put(skill);
    _load();
  }

  List<PracticeSession> sessionsFor(Skill skill) {
    final all = _sessionBox.getAll();
    final sessions =
        all.where((s) => s.skillName == skill.name).toList();
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  void removeSession(PracticeSession session, Skill skill) {
    skill.totalMinutes =
        (skill.totalMinutes - session.durationMinutes).clamp(0, 999999);
    _skillBox.put(skill);
    _sessionBox.remove(session.id);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class SkillsPage extends StatelessWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SkillsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSkillSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.skills;
        if (list.isEmpty) {
          return const Center(
              child: Text('No skills yet. Tap + to add one.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _SkillTile(skill: list[i], controller: c),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill, required this.controller});
  final Skill skill;
  final SkillsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = skill.totalHours;
    final lastPracticed = skill.lastPracticedAt != null
        ? DateFormat.yMMMd().format(skill.lastPracticedAt!)
        : 'Never';

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _SkillDetailPage(skill: skill, controller: controller),
        ),
      ),
      title: Text(skill.name),
      subtitle: Text(
        [
          '${hours.toStringAsFixed(1)} hrs',
          'Last: $lastPracticed',
          if (skill.category != null && skill.category!.isNotEmpty)
            skill.category!,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${hours.toStringAsFixed(1)}h',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail page
// ---------------------------------------------------------------------------

class _SkillDetailPage extends StatefulWidget {
  const _SkillDetailPage({required this.skill, required this.controller});
  final Skill skill;
  final SkillsController controller;

  @override
  State<_SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<_SkillDetailPage> {
  final _minCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _minCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.controller;

    final skill = c.skills.firstWhereOrNull((s) => s.id == widget.skill.id);
    if (skill == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Skill not found.')),
      );
    }

    final sessions = c.sessionsFor(skill);

    return Scaffold(
      appBar: AppBar(
        title: Text(skill.name),
        actions: [
          IconButton(
            tooltip: 'Delete skill',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              c.removeSkill(skill);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Total hours card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    skill.totalHours.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('total hours',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Log session
          Text('Log practice', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final mins = int.tryParse(_minCtrl.text.trim());
                    if (mins == null || mins <= 0) return;
                    c.logSession(
                      skill,
                      minutes: mins,
                      notes: _notesCtrl.text.trim().isNotEmpty
                          ? _notesCtrl.text.trim()
                          : null,
                    );
                    _minCtrl.clear();
                    _notesCtrl.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Text('No sessions logged yet.')
            else
              ...sessions.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s.durationMinutes} min'),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd().format(s.date),
                        if (s.notes != null && s.notes!.isNotEmpty)
                          s.notes!,
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        c.removeSession(s, skill);
                        setState(() {});
                      },
                    ),
                  )),
          ],
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

void _showSkillSheet(BuildContext context, SkillsController c,
    {Skill? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _SkillSheetContent(controller: c, existing: existing),
  );
}

class _SkillSheetContent extends StatefulWidget {
  const _SkillSheetContent({required this.controller, this.existing});
  final SkillsController controller;
  final Skill? existing;

  @override
  State<_SkillSheetContent> createState() => _SkillSheetContentState();
}

class _SkillSheetContentState extends State<_SkillSheetContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _notesCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _catCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _notesCtrl =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _catCtrl.dispose();
    _notesCtrl.dispose();
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
            Text(_isEdit ? 'Edit skill' : 'New skill',
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
              controller: _catCtrl,
              decoration: const InputDecoration(
                  labelText: 'Category (optional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
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
      final skill = widget.existing!;
      skill.name = name;
      skill.category =
          _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null;
      skill.notes =
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      widget.controller.updateSkill(skill);
    } else {
      widget.controller.addSkill(
        name: name,
        category:
            _catCtrl.text.trim().isNotEmpty ? _catCtrl.text.trim() : null,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
    }
    Navigator.pop(context);
  }
}
