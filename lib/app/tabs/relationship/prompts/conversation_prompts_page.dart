import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/conversation_prompts_controller.dart';

class ConversationPromptsPage extends StatelessWidget {
  const ConversationPromptsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ConversationPromptsController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation prompts'),
        actions: [
          IconButton(
            tooltip: 'Random prompt',
            icon: const Icon(Icons.shuffle),
            onPressed: () => _showRandom(context, c),
          ),
          Obx(() {
            final hide = c.hideAsked.value;
            return IconButton(
              tooltip: hide ? 'Show asked' : 'Hide asked',
              icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
              onPressed: () => c.hideAsked.value = !c.hideAsked.value,
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, c),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Category filter
          Obx(() {
            final cats = c.allCategories;
            return SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: c.categoryFilter.value == null,
                      onSelected: (_) => c.categoryFilter.value = null,
                    ),
                  ),
                  for (final cat in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat),
                        selected: c.categoryFilter.value == cat,
                        onSelected: (on) =>
                            c.categoryFilter.value = on ? cat : null,
                      ),
                    ),
                ],
              ),
            );
          }),
          // Prompt list
          Expanded(
            child: Obx(() {
              final list = c.prompts;
              if (list.isEmpty) {
                return const Center(child: Text('No prompts match.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (_, i) => _PromptTile(prompt: list[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showRandom(BuildContext context, ConversationPromptsController c) {
    final prompt = c.randomUnasked();
    if (prompt == null) {
      Get.snackbar('All done', 'You have asked all available prompts.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prompt.category),
        content: Text(prompt.question, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              c.markAsked(prompt);
              Navigator.pop(ctx);
            },
            child: const Text('Mark as asked'),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, ConversationPromptsController c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddPromptSheet(controller: c),
    );
  }
}

class _AddPromptSheet extends StatefulWidget {
  const _AddPromptSheet({required this.controller});
  final ConversationPromptsController controller;

  @override
  State<_AddPromptSheet> createState() => _AddPromptSheetState();
}

class _AddPromptSheetState extends State<_AddPromptSheet> {
  final _questionCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  @override
  void dispose() {
    _questionCtrl.dispose();
    _categoryCtrl.dispose();
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
            Text('Add your own prompt', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _questionCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What would you ask?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Deep, Fun, Future',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.controller.addCustom(
                  question: _questionCtrl.text,
                  category: _categoryCtrl.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.prompt});
  final PromptView prompt;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ConversationPromptsController>();
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        prompt.question,
        style: TextStyle(
          color: prompt.asked ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text(prompt.category, style: theme.textTheme.bodySmall),
          if (!prompt.isBuiltin) ...[
            const SizedBox(width: 8),
            Text('(custom)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                )),
          ],
        ],
      ),
      trailing: prompt.asked
          ? IconButton(
              tooltip: 'Mark unasked',
              icon: Icon(Icons.replay, color: theme.colorScheme.primary),
              onPressed: () => c.markUnasked(prompt),
            )
          : IconButton(
              tooltip: 'Mark as asked',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => c.markAsked(prompt),
            ),
    );
  }
}
