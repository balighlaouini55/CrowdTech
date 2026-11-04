// API gratuites du module Actus, en plus de Hacker News :
// - DEV Community (dev.to) : deuxième source d'articles tech, pour recouper
//   les informations ;
// - Wikipédia (REST) : contexte encyclopédique du sujet d'une actualité,
//   pour vérifier les faits avant de noter.

import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/news/domain/source_check.dart';

/// Résumé Wikipédia d'un sujet.
class WikiSummary {
  final String title;
  final String extract;
  final String url;
  final String? imageUrl;
  const WikiSummary({
    required this.title,
    required this.extract,
    required this.url,
    this.imageUrl,
  });
}

class NewsWebApi {
  NewsWebApi._();

  /// Articles récents les plus appréciés de DEV Community pour un [tag]
  /// (ai, security, cloud…), au format des actualités CrowdTech.
  static Future<List<Map<String, Object?>>> fetchDevTo({
    String tag = 'technology',
    int limit = 5,
  }) async {
    final json = await CrowdTechApi.getJson(
      Uri.https('dev.to', '/api/articles', {
        'tag': tag,
        'top': '7',
        'per_page': '$limit',
      }),
    );
    if (json is! List) throw const ApiException('Liste d’articles invalide.');
    return [
      for (final article in json)
        if (article is Map && article['title'] is String)
          {
            'title': article['title'],
            'source': 'DEV Community',
            'credibility': SourceCheck.devToCredibility(
              reactions: (article['public_reactions_count'] as num?) ?? 0,
              comments: (article['comments_count'] as num?) ?? 0,
            ),
            'tag': SourceCheck.tagOf(article['tag_list']),
            'summary':
                article['description']?.toString() ??
                'Article publié sur DEV Community.',
            'author': (article['user'] as Map?)?['name']?.toString(),
            'url': article['url']?.toString(),
            'publishedAt': article['published_timestamp']
                ?.toString()
                .split('T')
                .first,
          },
    ];
  }

  /// Nombre maximal de pages essayées pour un article (Wikipédia limite le
  /// nombre de requêtes).
  static const _maxCandidates = 3;

  /// Contexte Wikipédia d'une actualité : notions reconnues dans le titre,
  /// mots techniques, puis catégorie ; en dernier recours, recherche sur
  /// les titres de pages. Null si rien de pertinent n'est trouvé.
  static Future<WikiSummary?> factCheck(String title, {String? tag}) async {
    for (final page in SourceCheck.wikiCandidates(
      title,
      tag: tag,
    ).take(_maxCandidates)) {
      final summary = await pageSummary(page);
      if (summary != null) return summary;
    }
    return wikipediaSummary(SourceCheck.topicOf(title));
  }

  /// Page Wikipédia (en français) dont le titre correspond le mieux à
  /// [query], ou null si aucun titre ne partage de mot avec la recherche.
  static Future<WikiSummary?> wikipediaSummary(String query) async {
    if (query.trim().isEmpty) return null;
    final search = await CrowdTechApi.getJson(
      Uri.https('fr.wikipedia.org', '/w/rest.php/v1/search/title', {
        'q': query,
        'limit': '5',
      }),
    );
    final pages = search is Map ? search['pages'] : null;
    if (pages is! List) return null;
    for (final page in pages) {
      if (page is! Map || page['key'] is! String) continue;
      if (!SourceCheck.isRelevant('${page['title']}', query)) continue;
      return pageSummary(page['key']! as String);
    }
    return null;
  }

  /// Résumé de la page [key] (« RISC-V », « Start-up »…), ou null si elle
  /// n'existe pas ou n'est qu'une page d'homonymie.
  static Future<WikiSummary?> pageSummary(String key) async {
    final summary = await CrowdTechApi.getJson(
      Uri.https(
        'fr.wikipedia.org',
        '/api/rest_v1/page/summary/${key.replaceAll(' ', '_')}',
      ),
      allowNotFound: true,
    );
    if (summary is! Map || summary['extract'] is! String) return null;
    if (summary['type'] == 'disambiguation') return null;
    return WikiSummary(
      title: summary['title']?.toString() ?? key,
      extract: summary['extract']! as String,
      url:
          ((summary['content_urls'] as Map?)?['desktop'] as Map?)?['page']
              ?.toString() ??
          'https://fr.wikipedia.org/wiki/$key',
      imageUrl: (summary['thumbnail'] as Map?)?['source']?.toString(),
    );
  }
}
