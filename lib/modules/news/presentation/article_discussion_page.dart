// Discussion d'UNE actualité : sa note moyenne en étoiles, les avis et les
// commentaires publiés sur cet article uniquement.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/news/domain/article_feedback.dart';
import 'package:crowdtech/modules/news/domain/comment_moderation.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/modules/news/presentation/comment_form_page.dart';
import 'package:crowdtech/modules/news/presentation/review_form_page.dart';
import 'package:crowdtech/modules/news/presentation/widgets/wiki_context_card.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/star_rating.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ArticleDiscussionPage extends StatefulWidget {
  final NewsItem article;
  final String accountKey;
  const ArticleDiscussionPage({
    required this.article,
    required this.accountKey,
    super.key,
  });

  @override
  State<ArticleDiscussionPage> createState() => _ArticleDiscussionPageState();
}

class _ArticleDiscussionPageState extends State<ArticleDiscussionPage> {
  bool loading = true;
  String? loadError;
  List<ArticleReview> reviews = [];
  List<ArticleComment> comments = [];

  /// Signalements : commentId → comptes qui ont signalé.
  Map<int, Set<String>> reportMap = {};

  /// Tri des commentaires : « Pertinents » ou « Récents ».
  String commentSort = 'Pertinents';

  int get articleId => widget.article.id!;

  ArticleReview? get myReview => reviews
      .where((review) => review.ownerKey == widget.accountKey)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final allReviews = await NewsFeedback.loadReviews();
      final allComments = await NewsFeedback.loadComments();
      final allReports = await CommentModeration.reports();
      if (!mounted) return;
      setState(() {
        reportMap = allReports;
        reviews = allReviews.reversed
            .where((review) => review.articleId == articleId)
            .toList();
        comments = allComments
            .where((comment) => comment.articleId == articleId)
            .toList();
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger la discussion : $error';
      });
    }
  }

  Future<void> rate() async {
    if (widget.article.ownerKey == widget.accountKey) {
      context.showMessage(
        'C’est votre actualité : vous ne pouvez pas la noter vous-même.',
      );
      return;
    }
    final mine = myReview;
    final input = await Navigator.push<ReviewInput>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewFormPage(
          articleTitle: widget.article.title,
          initialStars: mine?.stars ?? 0,
          initialReview: mine?.review ?? '',
        ),
      ),
    );
    if (!mounted || input == null) return;
    try {
      await NewsFeedback.saveReview(
        articleId: articleId,
        articleTitle: widget.article.title,
        ownerKey: widget.accountKey,
        stars: input.stars,
        review: input.review,
      );
      await load();
      if (!mounted) return;
      context.showMessage(
        mine == null ? 'Merci pour votre note ⭐' : 'Votre note a été modifiée.',
      );
    } on Exception catch (error) {
      if (mounted) context.showMessage('Erreur SQLite : $error');
    }
  }

  Future<void> addComment() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CommentFormPage()),
    );
    if (!mounted || text == null) return;
    try {
      final comment = await NewsFeedback.addComment(
        articleId: articleId,
        articleTitle: widget.article.title,
        ownerKey: widget.accountKey,
        text: text,
      );
      if (!mounted) return;
      setState(() => comments.insert(0, comment));
      context.showMessage(
        comment.moderated
            ? 'Commentaire publié (certains mots ont été masqués).'
            : 'Commentaire publié dans la discussion.',
      );
    } on Exception catch (error) {
      // Refus de la modération automatique (spam, majuscules…).
      if (mounted) context.showMessage('$error');
    }
  }

  /// Commentaires affichés : un commentaire masqué n'est visible que par
  /// son auteur et l'administrateur.
  List<ArticleComment> get shownComments {
    final list = comments
        .where(
          (comment) =>
              !comment.hidden ||
              Permissions.isAdmin ||
              comment.ownerKey == widget.accountKey,
        )
        .toList();
    if (commentSort == 'Pertinents') {
      double score(ArticleComment comment) => CommentModeration.relevance({
        'text': comment.text,
        'createdAt': comment.createdAt,
      }, reportMap[comment.id]?.length ?? 0);
      list.sort((a, b) => score(b).compareTo(score(a)));
    }
    return list;
  }

  Future<void> reportComment(ArticleComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('🚩', style: TextStyle(fontSize: 32)),
        title: const Text('Signaler ce commentaire ?'),
        content: const Text(
          'Au bout de ${CommentModeration.reportThreshold} signalements, '
          'le commentaire est masqué automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final count = await CommentModeration.report(comment.id!);
      await load();
      if (!mounted) return;
      context.showMessage(
        count >= CommentModeration.reportThreshold
            ? 'Merci ! Le commentaire a été masqué.'
            : 'Merci, signalement enregistré '
                  '($count/${CommentModeration.reportThreshold}).',
      );
    } on Exception catch (error) {
      if (mounted) context.showMessage('$error');
    }
  }

  Future<void> restoreComment(ArticleComment comment) async {
    try {
      await CommentModeration.restore(comment.id!);
      await load();
      if (mounted) context.showMessage('Commentaire rétabli.');
    } on Exception catch (error) {
      if (mounted) context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      floatingActionButton: loading || loadError != null
          ? null
          : FloatingActionButton.extended(
              onPressed: addComment,
              backgroundColor: ModulePalette.news.start,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Commenter'),
            ),
      body: loading
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _articleHeader(),
                WikiContextCard(
                  title: widget.article.title,
                  tag: widget.article.tag,
                ),
                _ratingSummary(),
                _sectionTitle('Avis', reviews.length),
                if (reviews.isEmpty)
                  const _Hint('Aucune note pour l’instant. Soyez le premier !')
                else
                  ...reviews.map(_reviewTile),
                const SizedBox(height: 8),
                _sectionTitle('Commentaires', shownComments.length),
                if (comments.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final sort in const ['Pertinents', 'Récents'])
                          ChoiceChip(
                            label: Text(sort),
                            selected: commentSort == sort,
                            onSelected: (_) =>
                                setState(() => commentSort = sort),
                          ),
                      ],
                    ),
                  ),
                if (shownComments.isEmpty)
                  const EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'Aucun commentaire sur cette actualité.',
                    palette: ModulePalette.news,
                  )
                else
                  ...shownComments.map(_commentTile),
              ],
            ),
    );
  }

  Widget _articleHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ModulePalette.news.panel,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: ModulePalette.news.start.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ModulePalette.news.emoji}  ${widget.article.tag}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.article.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.article.source,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _ratingSummary() {
    final summary = RatingSummary(reviews);
    final mine = myReview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      summary.count == 0
                          ? '—'
                          : summary.average.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    StarRating(summary.average),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.count} note${summary.count > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (var stars = 5; stars >= 1; stars--)
                        _distributionBar(stars, summary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: rate,
                style: FilledButton.styleFrom(
                  backgroundColor: starColor,
                  foregroundColor: AppColors.ink,
                ),
                icon: const Icon(Icons.star_rounded),
                label: Text(
                  mine == null
                      ? 'Noter cette actualité'
                      : 'Ma note : ${mine.stars} ★ · Modifier',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _distributionBar(int stars, RatingSummary summary) {
    final share = summary.count == 0
        ? 0.0
        : summary.countFor(stars) / summary.count;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$stars',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const Icon(Icons.star_rounded, size: 12, color: starColor),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 7,
                color: starColor,
                backgroundColor: AppColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        StatusBadge('$count', tone: BadgeTone.info),
      ],
    ),
  );

  Widget _reviewTile(ArticleReview review) {
    final isMine = review.ownerKey == widget.accountKey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(review.authorName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMine
                            ? '${review.authorName} (moi)'
                            : review.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      StarRating(review.stars.toDouble(), size: 16),
                    ],
                  ),
                ),
                Text(
                  formatDate(review.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            if (review.review.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(review.review, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commentTile(ArticleComment comment) {
    final reports = reportMap[comment.id]?.length ?? 0;
    final mine = comment.ownerKey == widget.accountKey;
    return Opacity(
      opacity: comment.hidden ? 0.6 : 1,
      child: Card(
        child: ListTile(
          leading: _Avatar(comment.authorName),
          title: Text(comment.text),
          subtitle: Text(
            [
              comment.authorName,
              if (comment.createdAt != null) formatDateTime(comment.createdAt),
              if (comment.hidden) 'Masqué par la modération',
              if (!comment.hidden && reports > 0 && Permissions.isAdmin)
                '$reports signalement(s)',
            ].join(' • '),
          ),
          trailing: comment.hidden && Permissions.isAdmin
              ? IconButton(
                  tooltip: 'Rétablir le commentaire',
                  onPressed: () => restoreComment(comment),
                  icon: const Icon(Icons.visibility_rounded),
                )
              : mine || comment.hidden
              ? null
              : IconButton(
                  tooltip: 'Signaler',
                  onPressed: () => reportComment(comment),
                  icon: const Icon(Icons.outlined_flag_rounded),
                ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: ModulePalette.news.soft,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: ModulePalette.news.start,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
    child: Text(text, style: const TextStyle(color: AppColors.muted)),
  );
}
