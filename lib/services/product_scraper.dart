import 'dart:convert';

/// Extracted product information from a web page.
class ProductInfo {
  const ProductInfo({required this.name, this.price, required this.url});
  final String name;
  final double? price;
  final String url;
}

/// Scrapes product name and price from HTML using structured data and meta tags.
class ProductScraper {
  /// Parse HTML and extract product info. Returns null if no product data found.
  static ProductInfo? fromHtml(String html, String url) {
    final name = extractName(html);
    if (name == null) return null;
    final price = extractPrice(html);
    return ProductInfo(name: cleanName(name, fallbackUrl: url), price: price, url: url);
  }

  /// Extract product name. Priority: JSON-LD Product → og:title → <title>.
  static String? extractName(String html) {
    // 1. JSON-LD schema.org/Product
    final jsonLdName = _jsonLdProductField(html, 'name');
    if (jsonLdName != null && jsonLdName.isNotEmpty) return jsonLdName;

    // 2. og:title
    final ogTitle = _metaContent(html, 'og:title');
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    // 3. <title> tag
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true)
        .firstMatch(html);
    if (titleMatch != null) {
      final title = titleMatch.group(1)?.trim();
      if (title != null && title.isNotEmpty) return title;
    }

    return null;
  }

  /// Extract price. Priority: JSON-LD → og:price → meta product:price → patterns.
  static double? extractPrice(String html) {
    // 1. JSON-LD offers.price
    final jsonLdPrice = _jsonLdProductPrice(html);
    if (jsonLdPrice != null) return jsonLdPrice;

    // 2. og:price:amount
    final ogPrice = _metaContent(html, 'og:price:amount');
    if (ogPrice != null) {
      final p = parsePrice(ogPrice);
      if (p != null) return p;
    }

    // 3. product:price:amount
    final prodPrice = _metaContent(html, 'product:price:amount');
    if (prodPrice != null) {
      final p = parsePrice(prodPrice);
      if (p != null) return p;
    }

    // 4. Common price patterns in HTML
    final pricePatterns = [
      RegExp(r'class="[^"]*price[^"]*"[^>]*>\s*\$?([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'data-price="([\d,.]+)"', caseSensitive: false),
      RegExp(r'"price"\s*:\s*"?([\d,.]+)"?'),
    ];
    for (final pattern in pricePatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final p = parsePrice(match.group(1) ?? '');
        if (p != null && p > 0 && p < 100000) return p;
      }
    }

    return null;
  }

  /// Parse a price string like "$1,299.99" or "€29,99" into a double.
  static double? parsePrice(String raw) {
    // Strip everything except digits, dots, commas.
    var cleaned = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;

    // Handle European format: 1.500,00 (dot as thousands, comma as decimal).
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    if (lastComma > lastDot) {
      // Comma is the decimal separator.
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Dot is the decimal separator (or no decimal).
      cleaned = cleaned.replaceAll(',', '');
    }

    return double.tryParse(cleaned);
  }

  /// Clean product name: strip site suffixes, cap at 100 chars.
  static String cleanName(String raw, {String? fallbackUrl}) {
    var name = raw.trim();
    // Strip trailing site-name patterns.
    final suffixPattern = RegExp(r'\s*[-|–:]\s*[^-|–:]{3,}$');
    final stripped = name.replaceFirst(suffixPattern, '');
    if (stripped.length > 10) name = stripped;
    // Truncate at 100 chars (at word boundary if possible).
    if (name.length > 100) {
      final truncated = name.substring(0, 100);
      final lastSpace = truncated.lastIndexOf(' ');
      name = lastSpace > 50 ? truncated.substring(0, lastSpace) : truncated;
    }
    if (name.isEmpty && fallbackUrl != null) {
      final uri = Uri.tryParse(fallbackUrl);
      name = uri?.host ?? fallbackUrl;
    }
    return name;
  }

  // ─── HELPERS ───

  static String? _jsonLdProductField(String html, String field) {
    final scripts = RegExp(
      r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in scripts) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        final parsed = jsonDecode(raw);
        final product = _findProductNode(parsed);
        if (product != null && product[field] != null) {
          return product[field].toString();
        }
      } catch (_) {}
    }
    return null;
  }

  static double? _jsonLdProductPrice(String html) {
    final scripts = RegExp(
      r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in scripts) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        final parsed = jsonDecode(raw);
        final product = _findProductNode(parsed);
        if (product == null) continue;
        final offers = product['offers'];
        if (offers is Map && offers['price'] != null) {
          return parsePrice(offers['price'].toString());
        }
        if (offers is List && offers.isNotEmpty && offers[0]['price'] != null) {
          return parsePrice(offers[0]['price'].toString());
        }
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? _findProductNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (type == 'Product' || (type is List && type.contains('Product'))) return node;
      final graph = node['@graph'];
      if (graph is List) {
        for (final n in graph) {
          final r = _findProductNode(n);
          if (r != null) return r;
        }
      }
    } else if (node is List) {
      for (final n in node) {
        final r = _findProductNode(n);
        if (r != null) return r;
      }
    }
    return null;
  }

  static String? _metaContent(String html, String property) {
    final pattern = RegExp(
      '<meta[^>]*property=["\']$property["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match != null) return match.group(1);
    // Try reversed attribute order.
    final reversed = RegExp(
      '<meta[^>]*content=["\']([^"\']*)["\'][^>]*property=["\']$property["\']',
      caseSensitive: false,
    );
    return reversed.firstMatch(html)?.group(1);
  }
}
