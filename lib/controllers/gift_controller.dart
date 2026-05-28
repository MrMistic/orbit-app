import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

enum GiftTab { ideas, given }

class GiftController extends GetxController {
  final RxList<GiftEntry> _items = <GiftEntry>[].obs;
  final Rx<GiftTab> tab = GiftTab.ideas.obs;

  List<GiftEntry> get ideas => _items
      .where((g) => g.status == 'idea')
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<GiftEntry> get given => _items
      .where((g) => g.status == 'given')
      .toList()
    ..sort((a, b) => (b.givenAt ?? b.createdAt).compareTo(a.givenAt ?? a.createdAt));

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.giftBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.giftBox.getAll());
  }

  Future<void> add({
    required String title,
    String? notes,
    String status = 'idea',
    String? occasion,
    double? price,
    DateTime? givenAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.giftBox.put(GiftEntry(
      title: trimmed,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      status: status,
      occasion: (occasion?.trim().isEmpty ?? true) ? null : occasion!.trim(),
      price: price,
      givenAt: givenAt,
    ));
    _reload();
  }

  Future<void> updateGift(
    GiftEntry entry, {
    required String title,
    String? notes,
    required String status,
    String? occasion,
    double? price,
    DateTime? givenAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    entry.title = trimmed;
    entry.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    entry.status = status;
    entry.occasion = (occasion?.trim().isEmpty ?? true) ? null : occasion!.trim();
    entry.price = price;
    entry.givenAt = givenAt;
    ObjectBox.instance.giftBox.put(entry);
    _reload();
  }

  /// Move an idea to "given" status.
  Future<void> markGiven(GiftEntry entry) async {
    entry.status = 'given';
    entry.givenAt = DateTime.now();
    ObjectBox.instance.giftBox.put(entry);
    _reload();
  }

  Future<void> remove(GiftEntry entry) async {
    ObjectBox.instance.giftBox.remove(entry.id);
    _reload();
  }
}
