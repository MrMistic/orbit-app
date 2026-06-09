import 'package:http/http.dart' as http;

import '../app/tabs/recipes/recipe_editor_page.dart' show ImportedRecipe;
import 'product_scraper.dart';
import 'recipe_importer.dart';

enum ShareResultType { recipe, wishlist, disambiguation, noUrl, error }

class ShareResult {
  const ShareResult({
    required this.type,
    this.importedRecipe,
    this.productInfo,
    this.errorMessage,
    this.html,
    this.url,
  });
  final ShareResultType type;
  final ImportedRecipe? importedRecipe;
  final ProductInfo? productInfo;
  final String? errorMessage;
  final String? html; // for disambiguation fallback
  final String? url;
}

/// Orchestrates shared URL processing: extract → fetch → classify → result.
class ShareHandler {
  static final _urlPattern = RegExp(r'https?://[^\s<>"{}|\\^\[\]`]+');

  /// Extracts the first HTTP/HTTPS URL from arbitrary text.
  static String? extractUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }

  /// Process shared text: extract URL, fetch, detect type, return result.
  static Future<ShareResult> process(String sharedText) async {
    final url = extractUrl(sharedText);
    if (url == null) {
      return const ShareResult(type: ShareResultType.noUrl);
    }

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 16; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.7778.215 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        // Fetch failed — try to extract info from the URL itself.
        final fallback = _extractFromUrl(url, sharedText);
        if (fallback != null) {
          return ShareResult(type: ShareResultType.wishlist, productInfo: fallback, url: url);
        }
        return ShareResult(
          type: ShareResultType.error,
          errorMessage: 'Server returned ${response.statusCode}.',
          url: url,
        );
      }

      final html = response.body;

      // 1. Check for recipe JSON-LD (high specificity).
      final recipeJson = RecipeImporter.findRecipeJsonLd(html);
      if (recipeJson != null) {
        try {
          final imported = RecipeImporter.fromHtml(html, url);
          return ShareResult(type: ShareResultType.recipe, importedRecipe: imported, url: url);
        } catch (e) {
          return ShareResult(type: ShareResultType.error, errorMessage: 'Recipe parse failed: $e');
        }
      }

      // 2. Check for product data.
      final product = ProductScraper.fromHtml(html, url);
      if (product != null) {
        return ShareResult(type: ShareResultType.wishlist, productInfo: product, url: url);
      }

      // 3. Neither detected — disambiguation needed.
      return ShareResult(type: ShareResultType.disambiguation, html: html, url: url);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const ShareResult(
          type: ShareResultType.error,
          errorMessage: 'Import timed out. Check your connection.',
        );
      }
      // Network error — try URL-based fallback.
      final url = extractUrl(sharedText);
      if (url != null) {
        final fallback = _extractFromUrl(url, sharedText);
        if (fallback != null) {
          return ShareResult(type: ShareResultType.wishlist, productInfo: fallback, url: url);
        }
      }
      return ShareResult(type: ShareResultType.error, errorMessage: 'Error: $e');
    }
  }

  /// Fallback: extract product name from URL slug and shared text when fetch fails.
  static ProductInfo? _extractFromUrl(String url, String sharedText) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Many apps share text like "Product Name https://..." or "Check out Product Name on SiteName https://..."
    // Try to extract the text before the URL as the product name.
    final urlIndex = sharedText.indexOf(url);
    String? nameFromText;
    if (urlIndex > 5) {
      nameFromText = sharedText.substring(0, urlIndex).trim();
      // Strip common prefixes like "Check out", "Look at this"
      nameFromText = nameFromText
          .replaceFirst(RegExp(r'^(Check out|Look at|I found|Sharing|See)\s+', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s+(on|at|from|via)\s+\S+$', caseSensitive: false), '')
          .trim();
      if (nameFromText.length < 3) nameFromText = null;
    }

    // Extract from URL path slug (e.g. /product/air-jordan-1-retro → "Air Jordan 1 Retro").
    String? nameFromSlug;
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty && s.length > 3).toList();
    if (pathSegments.isNotEmpty) {
      // Use the last meaningful segment (usually the product slug).
      final slug = pathSegments.last;
      nameFromSlug = slug
          .replaceAll(RegExp(r'[-_]+'), ' ')
          .replaceAll(RegExp(r'\.\w+$'), '') // strip file extensions
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ')
          .trim();
      if (nameFromSlug.length < 3) nameFromSlug = null;
    }

    final name = nameFromText ?? nameFromSlug;
    if (name == null) return null;

    // Try to find a price in the shared text.
    final priceMatch = RegExp(r'\$[\d,]+\.?\d*').firstMatch(sharedText);
    double? price;
    if (priceMatch != null) {
      price = ProductScraper.parsePrice(priceMatch.group(0)!);
    }

    return ProductInfo(
      name: name.length > 100 ? name.substring(0, 100) : name,
      price: price,
      url: url,
    );
  }
}
