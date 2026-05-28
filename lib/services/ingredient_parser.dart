import '../database/models.dart';

/// Parses free-form ingredient lines into structured [Ingredient]s.
///
/// Heuristic, intentionally simple:
/// - Leading number (with optional decimal or fraction like "1/2") → quantity
/// - Next token is treated as the unit if it matches a known unit or unit
///   abbreviation; otherwise no unit is set
/// - Remaining text becomes the name (with anything after a comma stored as
///   the prep [Ingredient.note])
class IngredientParser {
  static const _knownUnits = <String>{
    'tsp', 'teaspoon', 'teaspoons',
    'tbsp', 'tablespoon', 'tablespoons',
    'cup', 'cups', 'c',
    'oz', 'ounce', 'ounces',
    'lb', 'lbs', 'pound', 'pounds',
    'g', 'gram', 'grams',
    'kg', 'kilogram', 'kilograms',
    'ml', 'milliliter', 'milliliters',
    'l', 'liter', 'liters',
    'pinch', 'pinches', 'dash', 'dashes',
    'clove', 'cloves',
    'slice', 'slices',
    'can', 'cans',
    'pkg', 'package', 'packages',
  };

  /// Parses one line. Returns null if the line is empty.
  static Ingredient? parseLine(String raw, {int order = 0}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Split off the trailing prep note after the first comma.
    String main = trimmed;
    String? note;
    final commaIdx = trimmed.indexOf(',');
    if (commaIdx > 0) {
      main = trimmed.substring(0, commaIdx).trim();
      final after = trimmed.substring(commaIdx + 1).trim();
      if (after.isNotEmpty) note = after;
    }

    final tokens = main.split(RegExp(r'\s+'));
    if (tokens.isEmpty) {
      return Ingredient(name: main, note: note, order: order);
    }

    double? quantity;
    int consumed = 0;

    final firstQty = _tryParseQuantity(tokens[0]);
    if (firstQty != null) {
      quantity = firstQty;
      consumed = 1;
      // Allow a second number token forming a mixed number ("1 1/2 cups").
      if (tokens.length > 1) {
        final second = _tryParseQuantity(tokens[1]);
        if (second != null && second < 1) {
          quantity = quantity + second;
          consumed = 2;
        }
      }
    }

    String? unit;
    if (consumed < tokens.length) {
      final candidate = tokens[consumed].toLowerCase().replaceAll('.', '');
      if (_knownUnits.contains(candidate)) {
        unit = tokens[consumed].replaceAll('.', '');
        consumed += 1;
      }
    }

    final name = tokens.sublist(consumed).join(' ').trim();
    return Ingredient(
      quantity: quantity,
      unit: unit,
      name: name.isEmpty ? main : name, // fallback to whole line if name empty
      note: note,
      order: order,
    );
  }

  /// Parses every non-empty line in [raw] into ingredients.
  static List<Ingredient> parseLines(String raw) {
    final lines = raw.split('\n');
    final out = <Ingredient>[];
    var order = 0;
    for (final line in lines) {
      final ing = parseLine(line, order: order);
      if (ing != null) {
        out.add(ing);
        order += 1;
      }
    }
    return out;
  }

  /// Parses "1 1/2", "1.5", "1/2", "1" → 1.5, 1.5, 0.5, 1.
  static double? _tryParseQuantity(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;
    if (t.contains('/')) {
      final parts = t.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) return num / den;
      }
      return null;
    }
    return double.tryParse(t);
  }
}
