import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

class ShoppingController extends GetxController {
  final RxList<ShoppingItem> _items = <ShoppingItem>[].obs;

  /// Items grouped: unchecked first (most recently added first), then checked.
  List<ShoppingItem> get items {
    final list = List<ShoppingItem>.from(_items);
    list.sort((a, b) {
      if (a.checked != b.checked) return a.checked ? 1 : -1;
      return b.addedAt.compareTo(a.addedAt);
    });
    return list;
  }

  int get uncheckedCount => _items.where((i) => !i.checked).length;

  @override
  void onInit() {
    super.onInit();
    _reload();
    final box = ObjectBox.instance.shoppingBox;
    box.query().watch(triggerImmediately: false).listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.shoppingBox.getAll());
  }

  /// Adds ingredients from a recipe. Items with the same lowercase name +
  /// matching unit get merged (quantities summed when both are numeric);
  /// otherwise a new line is created.
  Future<void> addFromRecipe(Recipe recipe) async {
    final box = ObjectBox.instance.shoppingBox;
    final existing = box.getAll().where((i) => !i.checked).toList();

    for (final ing in recipe.ingredientList) {
      final match = existing.firstWhereOrNull((e) =>
          e.name.toLowerCase() == ing.name.toLowerCase() &&
          (e.unit ?? '').toLowerCase() == (ing.unit ?? '').toLowerCase());

      if (match != null && match.quantity != null && ing.quantity != null) {
        match.quantity = match.quantity! + ing.quantity!;
        if (match.sourceRecipe != null &&
            !match.sourceRecipe!.contains(recipe.name)) {
          match.sourceRecipe = '${match.sourceRecipe}, ${recipe.name}';
        }
        box.put(match);
      } else if (match != null) {
        // Quantities not both numeric — append note rather than mangle data.
        if (match.sourceRecipe != null &&
            !match.sourceRecipe!.contains(recipe.name)) {
          match.sourceRecipe = '${match.sourceRecipe}, ${recipe.name}';
        }
        box.put(match);
      } else {
        box.put(ShoppingItem(
          name: ing.name,
          quantity: ing.quantity,
          unit: ing.unit,
          sourceRecipe: recipe.name,
        ));
      }
    }
    _reload();
  }

  Future<void> addManual(String name, {double? quantity, String? unit}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.shoppingBox.put(ShoppingItem(
      name: trimmed,
      quantity: quantity,
      unit: unit,
    ));
    _reload();
  }

  Future<void> toggleChecked(ShoppingItem item) async {
    item.checked = !item.checked;
    ObjectBox.instance.shoppingBox.put(item);
    _reload();
  }

  Future<void> remove(ShoppingItem item) async {
    ObjectBox.instance.shoppingBox.remove(item.id);
    _reload();
  }

  Future<void> clearChecked() async {
    final ids = _items.where((i) => i.checked).map((i) => i.id).toList();
    if (ids.isEmpty) return;
    ObjectBox.instance.shoppingBox.removeMany(ids);
    _reload();
  }

  Future<void> clearAll() async {
    final ids = _items.map((i) => i.id).toList();
    if (ids.isEmpty) return;
    ObjectBox.instance.shoppingBox.removeMany(ids);
    _reload();
  }
}
