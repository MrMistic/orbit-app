import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/ingredient_parser.dart';

enum RecipeSort { alphabetical, recentlyAdded }

class RecipeController extends GetxController {
  final RxList<Recipe> _items = <Recipe>[].obs;
  final RxString query = ''.obs;
  final Rx<RecipeSort> sort = RecipeSort.alphabetical.obs;
  final RxBool favoritesOnly = false.obs;
  final RxnString tagFilter = RxnString();

  /// All distinct tags across all recipes.
  List<String> get allTags {
    final set = <String>{};
    for (final r in _items) {
      set.addAll(r.tagList);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Filtered + sorted view.
  List<Recipe> get recipes {
    final q = query.value.trim().toLowerCase();
    final direction = sort.value;
    final favOnly = favoritesOnly.value;
    final tag = tagFilter.value;

    final list = _items.where((r) {
      if (favOnly && !r.favorite) return false;
      if (tag != null && !r.tagList.contains(tag)) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          (r.description?.toLowerCase().contains(q) ?? false) ||
          r.ingredientList.any((i) => i.name.toLowerCase().contains(q)) ||
          r.tagList.any((t) => t.toLowerCase().contains(q));
    }).toList();

    list.sort((a, b) {
      switch (direction) {
        case RecipeSort.alphabetical:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case RecipeSort.recentlyAdded:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _migrateLegacyIngredients();
    _reload();
    final box = ObjectBox.instance.recipeBox;
    box.query().watch(triggerImmediately: false).listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.recipeBox.getAll());
  }

  /// One-shot migration: any recipe with non-empty `ingredients` (legacy
  /// string field) but empty `ingredientList` gets parsed into structured
  /// ingredients, then has the legacy field cleared.
  void _migrateLegacyIngredients() {
    final box = ObjectBox.instance.recipeBox;
    final all = box.getAll();
    var changed = 0;
    for (final r in all) {
      if (r.ingredients.trim().isEmpty) continue;
      if (r.ingredientList.isNotEmpty) continue;
      final parsed = IngredientParser.parseLines(r.ingredients);
      if (parsed.isEmpty) continue;
      r.ingredientList.addAll(parsed);
      r.ingredients = '';
      box.put(r);
      changed += 1;
    }
    if (changed > 0) {
      // ignore: avoid_print
      print('RecipeController: migrated $changed legacy recipe(s)');
    }
  }

  void toggleSort() {
    sort.value = sort.value == RecipeSort.alphabetical
        ? RecipeSort.recentlyAdded
        : RecipeSort.alphabetical;
  }

  void toggleFavoritesOnly() => favoritesOnly.value = !favoritesOnly.value;

  void setTagFilter(String? tag) => tagFilter.value = tag;

  Future<Recipe> create({
    required String name,
    String? description,
    required List<Ingredient> ingredients,
    required String steps,
    int servings = 1,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    bool favorite = false,
    String? photoPath,
    List<String> tags = const [],
  }) async {
    final recipe = Recipe(
      name: name.trim(),
      description: _nullIfEmpty(description),
      steps: steps.trim(),
      servings: servings,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      favorite: favorite,
      photoPath: photoPath,
    );
    recipe.tagList = tags;
    _assignOrder(ingredients);
    recipe.ingredientList.addAll(ingredients);
    final id = ObjectBox.instance.recipeBox.put(recipe);
    recipe.id = id;
    _reload();
    return recipe;
  }

  Future<void> updateRecipe(
    Recipe recipe, {
    required String name,
    String? description,
    required List<Ingredient> ingredients,
    required String steps,
    required int servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    bool? favorite,
    String? photoPath,
    List<String>? tags,
  }) async {
    recipe.name = name.trim();
    recipe.description = _nullIfEmpty(description);
    recipe.steps = steps.trim();
    recipe.servings = servings;
    recipe.prepTimeMinutes = prepTimeMinutes;
    recipe.cookTimeMinutes = cookTimeMinutes;
    if (favorite != null) recipe.favorite = favorite;
    recipe.photoPath = photoPath;
    if (tags != null) recipe.tagList = tags;

    // Replace ingredients: remove old, add new.
    final ingBox = ObjectBox.instance.ingredientBox;
    final oldIds = recipe.ingredientList.map((i) => i.id).toList();
    recipe.ingredientList.clear();
    if (oldIds.isNotEmpty) ingBox.removeMany(oldIds);
    _assignOrder(ingredients);
    recipe.ingredientList.addAll(ingredients);

    ObjectBox.instance.recipeBox.put(recipe);
    _reload();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    recipe.favorite = !recipe.favorite;
    ObjectBox.instance.recipeBox.put(recipe);
    _reload();
  }

  Future<void> remove(Recipe recipe) async {
    // Cascade: remove orphaned ingredients first.
    final ingBox = ObjectBox.instance.ingredientBox;
    final ids = recipe.ingredientList.map((i) => i.id).toList();
    if (ids.isNotEmpty) ingBox.removeMany(ids);
    ObjectBox.instance.recipeBox.remove(recipe.id);
    _reload();
  }

  Recipe? findById(int id) => ObjectBox.instance.recipeBox.get(id);

  void _assignOrder(List<Ingredient> list) {
    for (var i = 0; i < list.length; i++) {
      list[i].order = i;
    }
  }

  String? _nullIfEmpty(String? s) {
    if (s == null) return null;
    final trimmed = s.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
