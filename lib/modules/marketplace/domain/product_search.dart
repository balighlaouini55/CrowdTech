// Moteur de recherche et de filtrage multi-critères du catalogue :
// texte, catégories, prix min/max, état, marque, note, stock, réputation du
// vendeur, et tri.

import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/shared/utils/text_normalizer.dart';

enum ProductSort {
  relevance('Pertinence'),
  priceAsc('Prix croissant'),
  priceDesc('Prix décroissant'),
  rating('Mieux notés'),
  newest('Nouveautés'),
  seller('Meilleurs vendeurs');

  final String label;
  const ProductSort(this.label);
}

class ProductFilter {
  final String query;
  final Set<String> categories;
  final Set<String> conditions;
  final Set<String> brands;
  final double? minPrice;
  final double? maxPrice;
  final double minRating;
  final bool inStockOnly;

  /// Score de réputation minimal du vendeur (0 = pas de filtre).
  final int minSellerScore;
  final ProductSort sort;

  const ProductFilter({
    this.query = '',
    this.categories = const {},
    this.conditions = const {},
    this.brands = const {},
    this.minPrice,
    this.maxPrice,
    this.minRating = 0,
    this.inStockOnly = false,
    this.minSellerScore = 0,
    this.sort = ProductSort.relevance,
  });

  /// Nombre de critères actifs (hors texte et tri), pour le badge du bouton.
  int get activeCount => [
    categories.isNotEmpty,
    conditions.isNotEmpty,
    brands.isNotEmpty,
    minPrice != null,
    maxPrice != null,
    minRating > 0,
    inStockOnly,
    minSellerScore > 0,
  ].where((active) => active).length;

  ProductFilter copyWith({
    String? query,
    Set<String>? categories,
    Set<String>? conditions,
    Set<String>? brands,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    double? minRating,
    bool? inStockOnly,
    int? minSellerScore,
    ProductSort? sort,
  }) => ProductFilter(
    query: query ?? this.query,
    categories: categories ?? this.categories,
    conditions: conditions ?? this.conditions,
    brands: brands ?? this.brands,
    minPrice: minPrice == null ? this.minPrice : minPrice(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    minRating: minRating ?? this.minRating,
    inStockOnly: inStockOnly ?? this.inStockOnly,
    minSellerScore: minSellerScore ?? this.minSellerScore,
    sort: sort ?? this.sort,
  );

  /// Mêmes critères, sans filtres (texte et tri conservés).
  ProductFilter cleared() => ProductFilter(query: query, sort: sort);
}

class ProductSearch {
  ProductSearch._();

  static String _norm(String text) => normalizeText(text);

  /// Pertinence textuelle : nom > marque > catégorie > description.
  static double textScore(ProductItem product, List<String> terms) {
    if (terms.isEmpty) return 1;
    var score = 0.0;
    for (final term in terms) {
      final name = _norm(product.name);
      var best = 0.0;
      if (name.startsWith(term)) {
        best = 4;
      } else if (name.contains(term)) {
        best = 3;
      } else if (_norm(product.brand ?? '').contains(term)) {
        best = 2.5;
      } else if (_norm(product.category).contains(term)) {
        best = 2;
      } else if (_norm(product.description ?? '').contains(term)) {
        best = 1;
      }
      if (best == 0) return 0;
      score += best;
    }
    return score;
  }

  /// Applique tous les critères puis trie. [sellerScores] associe chaque
  /// vendeur à son score de réputation.
  static List<ProductItem> apply(
    List<ProductItem> products,
    ProductFilter filter, {
    Map<String, int> sellerScores = const {},
  }) {
    final terms = _norm(filter.query)
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    int sellerScore(ProductItem product) =>
        sellerScores[product.ownerKey ?? ''] ?? 0;
    final scored = <(ProductItem, double, int)>[];
    for (final (index, product) in products.indexed) {
      final relevance = textScore(product, terms);
      if (relevance == 0) continue;
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(product.category)) {
        continue;
      }
      if (filter.conditions.isNotEmpty &&
          !filter.conditions.contains(product.condition ?? 'Neuf')) {
        continue;
      }
      if (filter.brands.isNotEmpty &&
          !filter.brands.contains(product.brand ?? '')) {
        continue;
      }
      if (filter.minPrice case final min? when product.price < min) continue;
      if (filter.maxPrice case final max? when product.price > max) continue;
      if (filter.minRating > 0 && (product.rating ?? 0) < filter.minRating) {
        continue;
      }
      if (filter.inStockOnly && !product.inStock) continue;
      if (filter.minSellerScore > 0 &&
          sellerScore(product) < filter.minSellerScore) {
        continue;
      }
      scored.add((product, relevance, index));
    }
    int compare((ProductItem, double, int) a, (ProductItem, double, int) b) {
      final order = switch (filter.sort) {
        ProductSort.relevance => b.$2.compareTo(a.$2),
        ProductSort.priceAsc => a.$1.price.compareTo(b.$1.price),
        ProductSort.priceDesc => b.$1.price.compareTo(a.$1.price),
        ProductSort.rating => (b.$1.rating ?? 0).compareTo(a.$1.rating ?? 0),
        ProductSort.newest => b.$3.compareTo(a.$3),
        ProductSort.seller => sellerScore(b.$1).compareTo(sellerScore(a.$1)),
      };
      // Égalité : ordre d'origine (tri stable).
      return order != 0 ? order : a.$3.compareTo(b.$3);
    }

    scored.sort(compare);
    return [for (final entry in scored) entry.$1];
  }
}
