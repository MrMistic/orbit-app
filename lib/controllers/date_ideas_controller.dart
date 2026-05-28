import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

class DateIdeasController extends GetxController {
  final RxList<DateIdea> _items = <DateIdea>[].obs;
  final RxnString categoryFilter = RxnString();
  final RxBool showDone = false.obs;

  /// All distinct categories across all ideas.
  List<String> get allCategories {
    final set = <String>{};
    for (final i in _items) {
      if (i.category.isNotEmpty) set.add(i.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Filtered view: undone first (newest first), then done at the bottom.
  List<DateIdea> get ideas {
    final cat = categoryFilter.value;
    final includeDone = showDone.value;

    final list = _items.where((i) {
      if (!includeDone && i.done) return false;
      if (cat != null && cat.isNotEmpty && i.category != cat) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.dateIdeaBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.dateIdeaBox.getAll());
  }

  Future<void> add(String title, {String? notes, String category = ''}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.dateIdeaBox.put(DateIdea(
      title: trimmed,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      category: category.trim(),
    ));
    _reload();
  }

  Future<void> updateIdea(
    DateIdea idea, {
    required String title,
    String? notes,
    required String category,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    idea.title = trimmed;
    idea.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    idea.category = category.trim();
    ObjectBox.instance.dateIdeaBox.put(idea);
    _reload();
  }

  Future<void> toggleDone(DateIdea idea) async {
    idea.done = !idea.done;
    idea.completedAt = idea.done ? DateTime.now() : null;
    ObjectBox.instance.dateIdeaBox.put(idea);
    _reload();
  }

  Future<void> remove(DateIdea idea) async {
    ObjectBox.instance.dateIdeaBox.remove(idea.id);
    _reload();
  }
}
