import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/tabs/recipes/recipe_editor_page.dart' show ImportedRecipe;

/// Imports a recipe from a URL by parsing JSON-LD data with `@type: Recipe`.
/// Most major recipe sites embed this for SEO.
class RecipeImporter {
  static Future<ImportedRecipe> fromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const ImportException('Invalid URL.');
    }

    final response = await http
        .get(uri, headers: {
          // Pretending to be a desktop browser. Some sites gate JSON-LD by UA.
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        })
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ImportException('Server returned ${response.statusCode}.');
    }

    final json = findRecipeJsonLd(response.body);
    if (json == null) {
      throw const ImportException(
          'No recipe data found on this page. The site may not embed structured recipe data.');
    }

    return _toImported(json);
  }

  /// Parses already-fetched HTML for recipe data. Throws ImportException if not found.
  static ImportedRecipe fromHtml(String html, String url) {
    final json = findRecipeJsonLd(html);
    if (json == null) {
      throw const ImportException(
          'No recipe data found on this page.');
    }
    return _toImported(json);
  }

  /// Searches the HTML for `<script type="application/ld+json">` blocks and
  /// returns the first one that describes a Recipe.
  static Map<String, dynamic>? findRecipeJsonLd(String html) {
    final pattern = RegExp(
      r'<script[^>]*type=["' "'" r']application/ld\+json["' "'" r'][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(html);
    for (final match in matches) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        final parsed = jsonDecode(raw);
        final found = _findRecipeNode(parsed);
        if (found != null) return found;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Walks the JSON-LD payload (which may be a single object, array, or
  /// `@graph` container) looking for a Recipe node.
  static Map<String, dynamic>? _findRecipeNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (_typeIsRecipe(type)) return node;
      final graph = node['@graph'];
      if (graph is List) {
        for (final n in graph) {
          final r = _findRecipeNode(n);
          if (r != null) return r;
        }
      }
    } else if (node is List) {
      for (final n in node) {
        final r = _findRecipeNode(n);
        if (r != null) return r;
      }
    }
    return null;
  }

  static bool _typeIsRecipe(dynamic type) {
    if (type == 'Recipe') return true;
    if (type is List && type.contains('Recipe')) return true;
    return false;
  }

  static ImportedRecipe _toImported(Map<String, dynamic> json) {
    final ingredients = _stringList(json['recipeIngredient']);
    final steps = _instructionsToText(json['recipeInstructions']);
    final yieldVal = _parseInt(json['recipeYield']);
    final prep = _isoDurationToMinutes(json['prepTime']);
    final cook = _isoDurationToMinutes(json['cookTime']);
    final keywords = _csvList(json['keywords']);
    final categories = _stringList(json['recipeCategory']);
    final cuisines = _stringList(json['recipeCuisine']);
    final tags = {...keywords, ...categories, ...cuisines}.toList();

    return ImportedRecipe(
      name: (json['name'] ?? 'Imported recipe').toString(),
      description: json['description']?.toString(),
      ingredients: ingredients,
      steps: steps,
      servings: yieldVal ?? 1,
      prepTimeMinutes: prep,
      cookTimeMinutes: cook,
      tags: tags,
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v == null) return const [];
    if (v is String) return [v.trim()].where((s) => s.isNotEmpty).toList();
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _csvList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString().trim()).toList();
    return v
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _instructionsToText(dynamic instructions) {
    if (instructions == null) return '';
    if (instructions is String) return instructions.trim();
    if (instructions is List) {
      final lines = <String>[];
      for (final step in instructions) {
        if (step is String) {
          lines.add(step.trim());
        } else if (step is Map<String, dynamic>) {
          final type = step['@type']?.toString();
          if (type == 'HowToSection') {
            final items = step['itemListElement'];
            if (items is List) {
              for (final item in items) {
                if (item is Map<String, dynamic> && item['text'] != null) {
                  lines.add(item['text'].toString().trim());
                }
              }
            }
          } else {
            final text = step['text']?.toString().trim();
            if (text != null && text.isNotEmpty) lines.add(text);
          }
        }
      }
      return lines.where((s) => s.isNotEmpty).join('\n');
    }
    return '';
  }

  /// Parses ISO 8601 durations like "PT45M", "PT1H30M", "PT2H".
  static int? _isoDurationToMinutes(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(s);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final total = hours * 60 + minutes;
    return total > 0 ? total : null;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final match = RegExp(r'\d+').firstMatch(v.toString());
    return match != null ? int.tryParse(match.group(0)!) : null;
  }
}

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
