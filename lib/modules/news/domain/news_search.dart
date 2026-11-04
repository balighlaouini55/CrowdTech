// Moteur de recherche des actualités : index inversé des mots, score de
// pertinence pondéré par la fiabilité, et filtrage par niveau de confiance.

import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/shared/utils/text_normalizer.dart';

/// Niveau de confiance d'une actualité, d'après son score de fiabilité.
enum TrustLevel {
  all('Toutes', 0),
  high('Très fiables', 75),
  medium('Fiables', 50),
  low('À vérifier', 0);

  final String label;
  final int minimum;
  const TrustLevel(this.label, this.minimum);

  /// Niveau d'une actualité (jamais [all]).
  static TrustLevel of(int credibility) => credibility >= 75
      ? high
      : credibility >= 50
      ? medium
      : low;

  bool accepts(int credibility) => this == all || of(credibility) == this;
}

/// Ordre des résultats.
enum NewsSort {
  relevance('Pertinence'),
  newest('Plus récentes'),
  credibility('Plus fiables');

  final String label;
  const NewsSort(this.label);
}

class NewsSearch {
  NewsSearch._();

  /// Mots trop courants, ignorés par l'index.
  static const _stopWords = {
    'le',
    'la',
    'les',
    'un',
    'une',
    'des',
    'de',
    'du',
    'et',
    'en',
    'au',
    'aux',
    'pour',
    'par',
    'sur',
    'dans',
    'avec',
    'the',
    'of',
    'and',
    'to',
    'a',
    'in',
    'is',
    'on',
    'for',
    'with',
  };

  /// Découpe un texte en mots normalisés (minuscules, sans accents).
  static List<String> tokenize(String text) =>
      normalizeText(text)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((word) => word.length > 1 && !_stopWords.contains(word))
          .toList();

  /// Index inversé : mot → (id de l'actualité → poids). Le titre et les
  /// étiquettes comptent plus que le résumé.
  static Map<String, Map<int, double>> buildIndex(List<NewsItem> items) {
    final index = <String, Map<int, double>>{};
    void add(String text, int id, double weight) {
      for (final word in tokenize(text)) {
        final postings = index.putIfAbsent(word, () => {});
        postings[id] = (postings[id] ?? 0) + weight;
      }
    }

    for (final (position, item) in items.indexed) {
      final id = item.id ?? -position - 1;
      add(item.title, id, 3);
      add(item.tag, id, 2);
      add(item.source, id, 1.5);
      add(item.author ?? '', id, 1);
      add(item.summary, id, 1);
    }
    return index;
  }

  /// Recherche : les mots de la requête peuvent être des débuts de mots
  /// (« crypt » trouve « crypto »). Le score final multiplie la pertinence
  /// par un bonus de fiabilité, pour remonter les sources sûres.
  static List<NewsItem> search(
    List<NewsItem> items, {
    String query = '',
    TrustLevel level = TrustLevel.all,
    NewsSort sort = NewsSort.relevance,
  }) {
    final filtered = items
        .where((item) => level.accepts(item.credibility))
        .toList();
    final terms = tokenize(query);
    final relevance = <NewsItem, double>{};
    if (terms.isEmpty) {
      for (final item in filtered) {
        relevance[item] = 1;
      }
    } else {
      final index = buildIndex(filtered);
      for (final (position, item) in filtered.indexed) {
        final id = item.id ?? -position - 1;
        var score = 0.0;
        var matchedAll = true;
        for (final term in terms) {
          var best = 0.0;
          for (final MapEntry(key: word, value: postings) in index.entries) {
            if (!word.startsWith(term)) continue;
            final weight = postings[id];
            if (weight == null) continue;
            // Mot exact préféré à un début de mot.
            final value = word == term ? weight : weight * 0.7;
            if (value > best) best = value;
          }
          if (best == 0) matchedAll = false;
          score += best;
        }
        if (matchedAll) relevance[item] = score;
      }
    }

    double rank(NewsItem item) =>
        relevance[item]! * (0.5 + item.credibility / 200);
    final results = relevance.keys.toList();
    // Position d'origine : départage les égalités (tri stable).
    final position = {for (final (i, item) in results.indexed) item: i};
    int compare(NewsItem a, NewsItem b) => switch (sort) {
      NewsSort.relevance => rank(b).compareTo(rank(a)),
      NewsSort.newest => (b.publishedAt ?? '').compareTo(a.publishedAt ?? ''),
      NewsSort.credibility => b.credibility.compareTo(a.credibility),
    };
    results.sort((a, b) {
      final order = compare(a, b);
      return order != 0 ? order : position[a]!.compareTo(position[b]!);
    });
    return results;
  }
}
