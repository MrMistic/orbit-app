import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

class PreferencesController extends GetxController {
  final RxList<PreferenceEntry> _items = <PreferenceEntry>[].obs;

  /// All distinct categories.
  List<String> get allCategories {
    final set = <String>{};
    for (final p in _items) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Entries grouped by category, sorted alphabetically within each group.
  Map<String, List<PreferenceEntry>> get grouped {
    final map = <String, List<PreferenceEntry>>{};
    for (final p in _items) {
      final cat = p.category.isEmpty ? 'Uncategorized' : p.category;
      map.putIfAbsent(cat, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.preferenceBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.preferenceBox.getAll());
  }

  Future<void> add({
    required String category,
    required String label,
    required String value,
  }) async {
    if (label.trim().isEmpty || value.trim().isEmpty) return;
    ObjectBox.instance.preferenceBox.put(PreferenceEntry(
      category: category.trim(),
      label: label.trim(),
      value: value.trim(),
    ));
    _reload();
  }

  Future<void> updateEntry(
    PreferenceEntry entry, {
    required String category,
    required String label,
    required String value,
  }) async {
    if (label.trim().isEmpty || value.trim().isEmpty) return;
    entry.category = category.trim();
    entry.label = label.trim();
    entry.value = value.trim();
    ObjectBox.instance.preferenceBox.put(entry);
    _reload();
  }

  Future<void> remove(PreferenceEntry entry) async {
    ObjectBox.instance.preferenceBox.remove(entry.id);
    _reload();
  }
}
