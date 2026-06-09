import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../controllers/cooking_session_controller.dart';
import '../../../controllers/recipe_controller.dart';
import '../../../controllers/shopping_controller.dart';
import '../../../database/models.dart';
import '../shopping/shopping_list_page.dart';
import 'recipe_editor_page.dart';

class RecipeDetailPage extends StatelessWidget {
  RecipeDetailPage({super.key, required this.recipeId});
  final int recipeId;
  // Per-page session, disposed when the page is removed.
  late final String _tag = 'cook_$recipeId';

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RecipeController>();
    final session = Get.put(CookingSessionController(), tag: _tag);

    return Obx(() {
      // Touch the recipes list so we rebuild after edits.
      final _ = c.recipes;
      final recipe = c.findById(recipeId);
      if (recipe == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Recipe not found.')),
        );
      }

      final ingredients = recipe.ingredientList.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final steps = _splitLines(recipe.steps);
      final totalMinutes =
          (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0);

      return Scaffold(
        appBar: AppBar(
          title: Text(recipe.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: recipe.favorite ? 'Unfavorite' : 'Favorite',
              icon: Icon(
                recipe.favorite ? Icons.star : Icons.star_border,
                color: recipe.favorite
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () => c.toggleFavorite(recipe),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    Get.to(() => RecipeEditorPage(existing: recipe));
                    break;
                  case 'share':
                    _share(recipe, ingredients, steps);
                    break;
                  case 'shopping':
                    _addToShopping(recipe);
                    break;
                  case 'delete':
                    _confirmDelete(context, c, recipe);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'shopping',
                  child: ListTile(
                    leading: Icon(Icons.shopping_cart_outlined),
                    title: Text('Add to shopping'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share as text'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (recipe.photoPath != null)
              Image.file(
                File(recipe.photoPath!),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.description != null &&
                      recipe.description!.isNotEmpty) ...[
                    Text(
                      recipe.description!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (recipe.tagList.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipe.tagList
                          .map((t) => Chip(
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MetaRow(
                    servings: recipe.servings,
                    prepMinutes: recipe.prepTimeMinutes,
                    cookMinutes: recipe.cookTimeMinutes,
                    totalMinutes: totalMinutes,
                  ),
                  if (recipe.cookTimeMinutes != null &&
                      recipe.cookTimeMinutes! > 0) ...[
                    const SizedBox(height: 12),
                    _CookTimerCard(
                      session: session,
                      cookMinutes: recipe.cookTimeMinutes!,
                      recipeName: recipe.name,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (ingredients.isNotEmpty) ...[
                    Text('Ingredients',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...ingredients.map(
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(i.display)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (steps.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Steps',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Obx(() {
                          final any = session.doneSteps.isNotEmpty;
                          return TextButton(
                            onPressed: any ? () => session.reset() : null,
                            child: const Text('Reset'),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...steps.asMap().entries.map(
                          (e) => _StepTile(
                            index: e.key,
                            text: e.value,
                            session: session,
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _share(Recipe r, List<Ingredient> ingredients, List<String> steps) {
    final buf = StringBuffer()..writeln(r.name);
    if (r.description != null && r.description!.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(r.description);
    }
    buf.writeln();
    final meta = <String>[];
    meta.add('${r.servings} serving${r.servings == 1 ? '' : 's'}');
    if (r.prepTimeMinutes != null) meta.add('${r.prepTimeMinutes} min prep');
    if (r.cookTimeMinutes != null) meta.add('${r.cookTimeMinutes} min cook');
    buf.writeln(meta.join(' • '));
    if (ingredients.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Ingredients:');
      for (final i in ingredients) {
        buf.writeln('• ${i.display}');
      }
    }
    if (steps.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Steps:');
      for (var idx = 0; idx < steps.length; idx++) {
        buf.writeln('${idx + 1}. ${steps[idx]}');
      }
    }
    Share.share(buf.toString(), subject: r.name);
  }

  Future<void> _addToShopping(Recipe r) async {
    final shop = Get.put(ShoppingController(), permanent: true);
    if (r.ingredientList.isEmpty) {
      Get.snackbar('Nothing to add', 'This recipe has no ingredients yet.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await shop.addFromRecipe(r);
    Get.snackbar(
      'Added to shopping',
      '${r.ingredientList.length} item${r.ingredientList.length == 1 ? '' : 's'} from ${r.name}',
      snackPosition: SnackPosition.BOTTOM,
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
          Get.to(() => const ShoppingListPage());
        },
        child: const Text('View'),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, RecipeController c, Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('"${recipe.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await c.remove(recipe);
      Get.back();
    }
  }

  List<String> _splitLines(String raw) => raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.text,
    required this.session,
  });

  final int index;
  final String text;
  final CookingSessionController session;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final done = session.isStepDone(index);
      final theme = Theme.of(context);
      return InkWell(
        onTap: () => session.toggleStep(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check,
                          size: 18, color: theme.colorScheme.onPrimary)
                      : Text('${index + 1}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _CookTimerCard extends StatelessWidget {
  const _CookTimerCard({
    required this.session,
    required this.cookMinutes,
    required this.recipeName,
  });

  final CookingSessionController session;
  final int cookMinutes;
  final String recipeName;

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final left = session.timerSecondsLeft.value;
      final running = left != null;
      return Card(
        elevation: 0,
        color: running
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: running ? theme.colorScheme.onPrimaryContainer : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running ? 'Cooking…' : 'Cook timer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: running
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      running ? _format(left) : '$cookMinutes min',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: running
                            ? theme.colorScheme.onPrimaryContainer
                            : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (running)
                FilledButton.tonal(
                  onPressed: session.cancelTimer,
                  child: const Text('Cancel'),
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: () => session.startTimer(
                    minutes: cookMinutes,
                    recipeName: recipeName,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.totalMinutes,
  });

  final int servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Stat(
              icon: Icons.people_outline,
              value: '$servings',
              label: servings == 1 ? 'serving' : 'servings',
            ),
            if (prepMinutes != null && prepMinutes! > 0)
              _Stat(
                icon: Icons.handyman_outlined,
                value: '$prepMinutes',
                label: 'min prep',
              ),
            if (cookMinutes != null && cookMinutes! > 0)
              _Stat(
                icon: Icons.local_fire_department_outlined,
                value: '$cookMinutes',
                label: 'min cook',
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
