// Modèles : la note (1 à 5 étoiles, avis facultatif) et le commentaire
// laissés sur UNE actualité précise.

/// Note d'un utilisateur sur une actualité (collection `news_votes`).
class ArticleReview {
  final int? id;
  final int articleId;
  final String ownerKey;
  final String authorName;
  final int stars;

  /// Avis écrit, facultatif (chaîne vide si l'utilisateur n'en a pas mis).
  final String review;
  final String? createdAt;

  const ArticleReview({
    this.id,
    required this.articleId,
    required this.ownerKey,
    required this.authorName,
    required this.stars,
    this.review = '',
    this.createdAt,
  });

  /// Retourne null pour une ancienne évaluation sans étoiles.
  static ArticleReview? tryFromMap(Map<String, Object?> map) {
    final articleId = map['articleId'];
    final stars = map['stars'];
    if (articleId is! num || stars is! num) return null;
    return ArticleReview(
      id: map['id'] as int?,
      articleId: articleId.toInt(),
      ownerKey: map['ownerKey']?.toString() ?? '',
      authorName: authorNameOf(map),
      stars: stars.toInt().clamp(1, 5),
      review: map['review']?.toString() ?? '',
      createdAt: map['createdAt']?.toString(),
    );
  }
}

/// Commentaire publié dans la discussion d'une actualité
/// (collection `news_comments`).
class ArticleComment {
  final int? id;
  final int? articleId;
  final String ownerKey;
  final String authorName;
  final String text;
  final String? createdAt;

  /// « Visible » ou « Masqué » (modération).
  final String status;

  /// true si des mots interdits ont été masqués automatiquement.
  final bool moderated;

  const ArticleComment({
    this.id,
    required this.articleId,
    required this.ownerKey,
    required this.authorName,
    required this.text,
    this.createdAt,
    this.status = 'Visible',
    this.moderated = false,
  });

  bool get hidden => status == 'Masqué';

  factory ArticleComment.fromMap(Map<String, Object?> map) => ArticleComment(
    id: map['id'] as int?,
    articleId: (map['articleId'] as num?)?.toInt(),
    ownerKey: map['ownerKey']?.toString() ?? '',
    authorName: authorNameOf(map),
    text: map['text']?.toString() ?? '',
    createdAt: map['createdAt']?.toString(),
    status: map['status']?.toString() ?? 'Visible',
    moderated: map['moderated'] == true,
  );
}

/// Nom de l'auteur enregistré, sinon le début de son email.
String authorNameOf(Map<String, Object?> map) {
  final name = map['authorName']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = map['ownerKey']?.toString() ?? '';
  return email.isEmpty ? 'Membre' : email.split('@').first;
}

/// Résumé des notes d'une actualité : moyenne, nombre et répartition.
class RatingSummary {
  final List<ArticleReview> reviews;
  const RatingSummary(this.reviews);

  int get count => reviews.length;

  double get average => reviews.isEmpty
      ? 0
      : reviews.map((review) => review.stars).reduce((a, b) => a + b) /
            reviews.length;

  /// Nombre de notes pour chaque valeur d'étoiles (1 à 5).
  int countFor(int stars) =>
      reviews.where((review) => review.stars == stars).length;

  /// Poids du score de départ, en nombre d'avis fictifs : quelques notes ne
  /// suffisent pas à rendre une actualité « Très fiable » (ou à la discréditer).
  static const priorWeight = 3;

  /// Score de départ d'une actualité sans indice sur sa source.
  static const neutralPrior = 50;

  /// Score de fiabilité par évaluation des pairs : moyenne bayésienne entre le
  /// score de départ de la source ([prior], en %) et les notes (5 étoiles =
  /// 100 %). Plus il y a de notes, plus elles pèsent.
  int credibilityFrom(int prior) {
    final start = prior > 0 ? prior : neutralPrior;
    return ((start * priorWeight + average * 20 * count) /
            (priorWeight + count))
        .round();
  }
}
