import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

class ImportantDatesController extends GetxController {
  final RxList<ImportantDate> _items = <ImportantDate>[].obs;

  /// Sorted by next upcoming first.
  List<ImportantDate> get dates {
    final list = List<ImportantDate>.from(_items);
    list.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.importantDateBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.importantDateBox.getAll());
  }

  Future<void> add({
    required String title,
    String? notes,
    required DateTime date,
    bool recurring = true,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.importantDateBox.put(ImportantDate(
      title: trimmed,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      date: date,
      recurring: recurring,
    ));
    _reload();
  }

  Future<void> updateDate(
    ImportantDate entry, {
    required String title,
    String? notes,
    required DateTime date,
    required bool recurring,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    entry.title = trimmed;
    entry.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    entry.date = date;
    entry.recurring = recurring;
    ObjectBox.instance.importantDateBox.put(entry);
    _reload();
  }

  Future<void> remove(ImportantDate entry) async {
    ObjectBox.instance.importantDateBox.remove(entry.id);
    _reload();
  }
}
