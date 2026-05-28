import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/todo_controller.dart';
import '../../database/models.dart';

class TodosTab extends StatelessWidget {
  const TodosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(TodoController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          Obx(() {
            final earliest = c.sort.value == TodoSort.earliestFirst;
            return IconButton(
              tooltip: earliest ? 'Earliest first' : 'Latest first',
              icon: Icon(earliest ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: c.toggleSort,
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTodoSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final list = c.todos;
        if (list.isEmpty) {
          return const Center(child: Text('Nothing to do. Tap + to add a todo.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _TodoTile(todo: list[i]),
        );
      }),
    );
  }
}

void _showTodoSheet(BuildContext context, TodoController c, {Todo? existing}) {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final dueDate = Rx<DateTime?>(existing?.dueDate);
  final isEdit = existing != null;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? 'Edit todo' : 'New todo',
              style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            autofocus: !isEdit,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Obx(() {
            final d = dueDate.value;
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      d == null
                          ? 'Add due date (optional)'
                          : 'Due ${DateFormat.yMMMd().format(d)}',
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: d ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked != null) dueDate.value = picked;
                    },
                  ),
                ),
                if (d != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close),
                    onPressed: () => dueDate.value = null,
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final notes = notesCtrl.text.trim();
              final cleanNotes = notes.isEmpty ? null : notes;
              if (isEdit) {
                c.updateTodo(
                  existing,
                  title: titleCtrl.text,
                  notes: cleanNotes,
                  dueDate: dueDate.value,
                );
              } else {
                c.add(
                  titleCtrl.text,
                  notes: cleanNotes,
                  dueDate: dueDate.value,
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    ),
  );
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.todo});
  final Todo todo;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TodoController>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => c.remove(todo),
      child: ListTile(
        onTap: () => _showTodoSheet(context, c, existing: todo),
        leading: Checkbox(
          value: todo.done,
          onChanged: (_) => c.toggle(todo),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final hasNotes = todo.notes != null && todo.notes!.isNotEmpty;
    final due = _dueLabel();

    if (!hasNotes && due == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasNotes) Text(todo.notes!),
        if (due != null)
          Text(
            due.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: due.overdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: due.overdue ? FontWeight.w600 : null,
            ),
          ),
      ],
    );
  }

  _DueLabel? _dueLabel() {
    final due = todo.dueDate;
    if (due == null) return null;

    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final diff = dueDay.difference(todayDay).inDays;

    final overdue = !todo.done && diff < 0;
    String text;
    if (diff == 0) {
      text = 'Due today';
    } else if (diff == 1) {
      text = 'Due tomorrow';
    } else if (diff == -1) {
      text = 'Due yesterday';
    } else if (diff > 1 && diff <= 7) {
      text = 'Due in $diff days';
    } else {
      text = 'Due ${DateFormat.yMMMd().format(due)}';
    }
    return _DueLabel(text: text, overdue: overdue);
  }
}

class _DueLabel {
  const _DueLabel({required this.text, required this.overdue});
  final String text;
  final bool overdue;
}
