import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/recipe_controller.dart';
import '../../../database/models.dart';
import '../../../services/recipe_importer.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor_page.dart';

class RecipeListPage extends StatelessWidget {
  const RecipeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(RecipeController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          Obx(() {
            final favOn = c.favoritesOnly.value;
            return IconButton(
              tooltip: favOn ? 'Show all' : 'Favorites only',
              icon: Icon(favOn ? Icons.star : Icons.star_border),
              onPressed: c.toggleFavoritesOnly,
            );
          }),
          Obx(() {
            final alpha = c.sort.value == RecipeSort.alphabetical;
            return IconButton(
              tooltip: alpha ? 'A-Z' : 'Recently added',
              icon: Icon(alpha ? Icons.sort_by_alpha : Icons.schedule),
              onPressed: c.toggleSort,
            );
          }),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import') _importDialog(context, c);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.link),
                  title: Text('Import from URL'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search recipes',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => c.query.value = v,
                ),
                const SizedBox(height: 8),
                Obx(() => _TagBar(
                      tags: c.allTags,
                      selected: c.tagFilter.value,
                      onSelect: c.setTagFilter,
                    )),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New recipe'),
        onPressed: () => Get.to(() => const RecipeEditorPage()),
      ),
      body: Obx(() {
        final list = c.recipes;
        if (list.isEmpty) {
          if (c.query.value.isNotEmpty ||
              c.favoritesOnly.value ||
              c.tagFilter.value != null) {
            return const Center(child: Text('No recipes match.'));
          }
          return const _EmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
          itemCount: list.length,
          itemBuilder: (_, i) => _RecipeCard(recipe: list[i]),
        );
      }),
    );
  }

  Future<void> _importDialog(BuildContext context, RecipeController c) async {
    final urlCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from URL'),
        content: TextField(
          controller: urlCtrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/recipe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final imported = await RecipeImporter.fromUrl(result);
      Get.back(); // dismiss loading
      Get.to(() => RecipeEditorPage(imported: imported));
    } on ImportException catch (e) {
      Get.back();
      Get.snackbar('Import failed', e.message,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.back();
      Get.snackbar('Import failed', 'Could not load that page.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({
    required this.tags,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          const SizedBox(width: 6),
          for (final t in tags) ...[
            FilterChip(
              label: Text(t),
              selected: selected == t,
              onSelected: (on) => onSelect(on ? t : null),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No recipes yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tap "New recipe" to start, or use the menu to import from a URL.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RecipeController>();
    final theme = Theme.of(context);
    final totalMinutes =
        (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => RecipeDetailPage(recipeId: recipe.id)),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: recipe.photoPath != null
                  ? Image.file(
                      File(recipe.photoPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (_, _, _) => _PhotoPlaceholder(theme: theme),
                    )
                  : _PhotoPlaceholder(theme: theme),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(recipe.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 36),
                          icon: Icon(
                            recipe.favorite ? Icons.star : Icons.star_border,
                            color: recipe.favorite
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => c.toggleFavorite(recipe),
                        ),
                      ],
                    ),
                    if (recipe.description != null &&
                        recipe.description!.isNotEmpty)
                      Text(
                        recipe.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _MetaChip(
                          icon: Icons.people_outline,
                          label:
                              '${recipe.servings} serving${recipe.servings == 1 ? '' : 's'}',
                        ),
                        if (totalMinutes > 0)
                          _MetaChip(
                            icon: Icons.timer_outlined,
                            label: '$totalMinutes min',
                          ),
                        for (final t in recipe.tagList.take(3))
                          _MetaChip(icon: Icons.label_outline, label: t),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
