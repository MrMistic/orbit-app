import 'dart:math';

import 'package:get/get.dart';

import '../data/builtin_prompts.dart';
import '../database/models.dart';
import '../database/object_box.dart';

class ConversationPromptsController extends GetxController {
  final RxList<ConversationPrompt> _dbItems = <ConversationPrompt>[].obs;
  final RxnString categoryFilter = RxnString();
  final RxBool hideAsked = false.obs;

  final _rng = Random();

  /// All categories (built-in + user-created).
  List<String> get allCategories {
    final set = <String>{...builtinPrompts.keys};
    for (final p in _dbItems) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Combined list of prompts: built-in (with DB overlay for asked state)
  /// plus user-created ones.
  List<PromptView> get prompts {
    final cat = categoryFilter.value;
    final hide = hideAsked.value;
    final result = <PromptView>[];

    // Built-in prompts.
    for (final entry in builtinPrompts.entries) {
      if (cat != null && entry.key != cat) continue;
      for (final q in entry.value) {
        final dbMatch = _findDbMatch(q);
        final asked = dbMatch?.asked ?? false;
        if (hide && asked) continue;
        result.add(PromptView(
          question: q,
          category: entry.key,
          asked: asked,
          isBuiltin: true,
          dbId: dbMatch?.id,
        ));
      }
    }

    // User-created prompts.
    for (final p in _dbItems.where((p) => p.userCreated)) {
      if (cat != null && p.category != cat) continue;
      if (hide && p.asked) continue;
      result.add(PromptView(
        question: p.question,
        category: p.category,
        asked: p.asked,
        isBuiltin: false,
        dbId: p.id,
      ));
    }

    return result;
  }

  /// Pick a random unasked prompt (respects current category filter).
  PromptView? randomUnasked() {
    final unasked = prompts.where((p) => !p.asked).toList();
    if (unasked.isEmpty) return null;
    return unasked[_rng.nextInt(unasked.length)];
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.conversationPromptBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _dbItems.assignAll(ObjectBox.instance.conversationPromptBox.getAll());
  }

  ConversationPrompt? _findDbMatch(String question) {
    for (final p in _dbItems) {
      if (!p.userCreated && p.question == question) return p;
    }
    return null;
  }

  Future<void> markAsked(PromptView view) async {
    final box = ObjectBox.instance.conversationPromptBox;
    if (view.dbId != null && view.dbId! > 0) {
      final entry = box.get(view.dbId!);
      if (entry != null) {
        entry.asked = true;
        entry.askedAt = DateTime.now();
        box.put(entry);
      }
    } else {
      // First time marking a built-in prompt — create a DB entry.
      box.put(ConversationPrompt(
        question: view.question,
        category: view.category,
        asked: true,
        userCreated: false,
        askedAt: DateTime.now(),
      ));
    }
    _reload();
  }

  Future<void> markUnasked(PromptView view) async {
    if (view.dbId == null || view.dbId == 0) return;
    final box = ObjectBox.instance.conversationPromptBox;
    final entry = box.get(view.dbId!);
    if (entry != null) {
      entry.asked = false;
      entry.askedAt = null;
      box.put(entry);
    }
    _reload();
  }

  Future<void> addCustom({
    required String question,
    String category = '',
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.conversationPromptBox.put(ConversationPrompt(
      question: trimmed,
      category: category.trim(),
      userCreated: true,
    ));
    _reload();
  }

  Future<void> removeCustom(PromptView view) async {
    if (view.dbId == null || view.dbId == 0) return;
    ObjectBox.instance.conversationPromptBox.remove(view.dbId!);
    _reload();
  }
}

/// Unified view model for display — merges built-in and user-created prompts.
class PromptView {
  const PromptView({
    required this.question,
    required this.category,
    required this.asked,
    required this.isBuiltin,
    this.dbId,
  });

  final String question;
  final String category;
  final bool asked;
  final bool isBuiltin;
  final int? dbId;
}

// Re-export for use in the page.
// Re-export alias removed — PromptView is already public.
