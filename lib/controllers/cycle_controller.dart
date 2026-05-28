import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/cycle_predictor.dart';

class CycleController extends GetxController {
  final RxList<CycleEntry> entries = <CycleEntry>[].obs;
  final Rxn<CyclePrediction> prediction = Rxn<CyclePrediction>();
  final RxList<CyclePrediction> futurePredictions = <CyclePrediction>[].obs;

  @override
  void onInit() {
    super.onInit();
    _reload();
    final box = ObjectBox.instance.cycleBox;
    box.query().watch(triggerImmediately: false).listen((_) => _reload());
  }

  void _reload() {
    final all = ObjectBox.instance.cycleBox.getAll()
      ..sort((a, b) => a.date.compareTo(b.date));
    entries.assignAll(all);
    prediction.value = CyclePredictor.predict(all);
    futurePredictions.assignAll(CyclePredictor.predictMultiple(all));
  }

  /// Returns the entry for [date] (date-only) if one exists.
  CycleEntry? entryFor(DateTime date) {
    final dd = DateTime(date.year, date.month, date.day);
    for (final e in entries) {
      final ed = DateTime(e.date.year, e.date.month, e.date.day);
      if (ed == dd) return e;
    }
    return null;
  }

  Future<void> setForDate(
    DateTime date, {
    required int flow,
    String? note,
    List<String>? symptoms,
  }) async {
    final box = ObjectBox.instance.cycleBox;
    final existing = entryFor(date);
    if (existing != null) {
      existing.flow = flow;
      existing.note = (note?.trim().isEmpty ?? true) ? null : note!.trim();
      if (symptoms != null) existing.symptoms = symptoms;
      box.put(existing);
    } else {
      final entry = CycleEntry(
        date: DateTime(date.year, date.month, date.day),
        flow: flow,
        note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      );
      if (symptoms != null) entry.symptoms = symptoms;
      box.put(entry);
    }
    _reload();
  }

  Future<void> clearDate(DateTime date) async {
    final existing = entryFor(date);
    if (existing == null) return;
    ObjectBox.instance.cycleBox.remove(existing.id);
    _reload();
  }
}
