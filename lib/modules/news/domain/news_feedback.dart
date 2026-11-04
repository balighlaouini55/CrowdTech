// Notes et commentaires des actualités : chaque note et chaque commentaire
// est rattaché à UNE actualité (articleId).

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/news/data/news_repository.dart';
import 'package:crowdtech/modules/news/domain/article_feedback.dart';
import 'package:crowdtech/modules/news/domain/comment_moderation.dart';

class NewsFeedback {
  NewsFeedback._();

  /// Notes valides (avec étoiles) de toutes les actualités.
  static Future<List<ArticleReview>> loadReviews() async => [
    for (final row in await NewsRepository.votes.all())
      ?ArticleReview.tryFromMap(row),
  ];

  /// Commentaires de toutes les actualités, du plus récent au plus ancien.
  static Future<List<ArticleComment>> loadComments() async => [
    for (final row in (await NewsRepository.comments.all()).reversed)
      if (row['text']?.toString().trim().isNotEmpty ?? false)
        ArticleComment.fromMap(row),
  ];

  /// Enregistre la note d'un utilisateur. Une seule note par utilisateur et
  /// par actualité : noter à nouveau remplace l'ancienne note.
  /// La fiabilité de l'actualité est recalculée à partir de toutes les notes.
  /// Retourne la nouvelle fiabilité (en %).
  static Future<int> saveReview({
    required int articleId,
    required String articleTitle,
    required String ownerKey,
    required int stars,
    String review = '',
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError.value(stars, 'stars', 'La note va de 1 à 5.');
    }
    final payload = {
      'articleId': articleId,
      'title': articleTitle,
      'ownerKey': ownerKey,
      'authorName': CrowdTechSession.name ?? '',
      'stars': stars,
      'review': review.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    // L'auteur ne peut pas noter son propre article (sinon il pourrait
    // gonfler lui-même sa fiabilité).
    final article = await NewsRepository.articles.byId(articleId);
    if (article != null && article['ownerKey'] == ownerKey) {
      throw const RuleException(
        'C’est votre actualité : vous ne pouvez pas la noter vous-même.',
      );
    }
    final votes = await NewsRepository.votes.all();
    final mine = votes.where(
      (vote) => vote['articleId'] == articleId && vote['ownerKey'] == ownerKey,
    );
    if (mine.isEmpty) {
      await NewsRepository.votes.add(payload);
    } else {
      await NewsRepository.votes.update(mine.first['id']! as int, payload);
      // Anciennes évaluations en double du même utilisateur : supprimées.
      for (final duplicate in mine.skip(1)) {
        await NewsRepository.votes.remove(duplicate['id']! as int);
      }
    }
    return _updateCredibility(articleId);
  }

  static Future<int> _updateCredibility(int articleId) async {
    final summary = RatingSummary([
      for (final review in await loadReviews())
        if (review.articleId == articleId) review,
    ]);
    final article = await NewsRepository.articles.byId(articleId);
    if (article == null) {
      throw Exception('L’actualité notée est introuvable.');
    }
    // Le score d'origine de la source est gardé pour les calculs suivants.
    final source =
        (article['sourceCredibility'] ?? article['credibility']) as num? ?? 0;
    final credibility = summary.credibilityFrom(source.toInt());
    await NewsRepository.articles.update(
      articleId,
      {
        ...article,
        'sourceCredibility': source.toInt(),
        'credibility': credibility,
      }..remove('id'),
    );
    return credibility;
  }

  /// Ajoute un commentaire dans la discussion d'une actualité.
  static Future<ArticleComment> addComment({
    required int articleId,
    required String articleTitle,
    required String ownerKey,
    required String text,
  }) async {
    // Filtrage automatique : spam refusé, mots interdits masqués.
    final moderation = CommentModeration.analyze(text);
    if (!moderation.accepted) throw RuleException(moderation.reason!);
    final payload = {
      'articleId': articleId,
      'articleTitle': articleTitle,
      'ownerKey': ownerKey,
      'authorName': CrowdTechSession.name ?? '',
      'text': moderation.text,
      'status': CommentStatus.visible,
      if (moderation.verdict == ModerationVerdict.masked) 'moderated': true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final id = await NewsRepository.comments.add(payload);
    return ArticleComment.fromMap({'id': id, ...payload});
  }
}
