// Écran Actualités : liste, recherche, notes en étoiles et discussion de
// chaque article.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/news/data/news_repository.dart';
import 'package:crowdtech/modules/news/data/sample_news.dart';
import 'package:crowdtech/modules/news/domain/article_feedback.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/modules/news/domain/news_search.dart';
import 'package:crowdtech/modules/news/presentation/article_discussion_page.dart';
import 'package:crowdtech/modules/news/presentation/article_form_page.dart';
import 'package:crowdtech/modules/news/presentation/article_management_page.dart';
import 'package:crowdtech/modules/news/presentation/review_form_page.dart';
import 'package:crowdtech/modules/news/presentation/widgets/article_card.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/pages/record_list_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/reload_on_sync.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class NewsScreen extends StatefulWidget {
  final String accountKey;
  const NewsScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with ReloadOnSync<NewsScreen> {
  @override
  void reloadAfterSync() => loadItems();

  String query = '';
  TrustLevel trustLevel = TrustLevel.all;
  NewsSort newsSort = NewsSort.newest;

  /// Actualités trouvées, filtrées par niveau de confiance et triées.
  List<NewsItem> get searchResults =>
      NewsSearch.search(items, query: query, level: trustLevel, sort: newsSort);
  List<ArticleReview> reviews = [];
  List<ArticleComment> comments = [];
  bool loading = true;
  String? loadError;

  final items = <NewsItem>[...sampleNews];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final rows = await NewsRepository.articles.seeded(
        sampleNews.map((item) => item.toMap()).toList(),
      );
      final savedReviews = await NewsFeedback.loadReviews();
      final savedComments = await NewsFeedback.loadComments();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(rows.map(NewsItem.fromMap));
        sortNewestFirst();
        reviews = savedReviews;
        comments = savedComments;
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger les actualités : $error';
      });
    }
  }

  /// Même ordre à l'ouverture et après un ajout : date de publication la plus
  /// récente d'abord ; les articles sans date suivent, dans l'ordre
  /// d'enregistrement.
  void sortNewestFirst() {
    items.sort((a, b) {
      final byDate = (b.publishedAt ?? '').compareTo(a.publishedAt ?? '');
      return byDate != 0 ? byDate : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  }

  Future<void> addArticle() async {
    final article = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const ArticleFormPage()),
    );
    if (!mounted || article == null) return;
    try {
      final id = await NewsRepository.articles.add({
        ...article,
        'credibility': 0,
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() {
        items.add(
          NewsItem.fromMap({
            'id': id,
            ...article,
            'credibility': 0,
            'ownerKey': widget.accountKey,
          }),
        );
        sortNewestFirst();
      });
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    context.showMessage('Article enregistré. Fiabilité à vérifier.');
  }

  RatingSummary summaryOf(NewsItem article) => RatingSummary([
    for (final review in reviews)
      if (review.articleId == article.id) review,
  ]);

  ArticleReview? myReviewOf(NewsItem article) => reviews
      .where(
        (review) =>
            review.articleId == article.id &&
            review.ownerKey == widget.accountKey,
      )
      .firstOrNull;

  int commentCountOf(NewsItem article) =>
      comments.where((comment) => comment.articleId == article.id).length;

  /// Note de 1 à 5 étoiles avec un avis facultatif. Une seule note par
  /// utilisateur et par article : noter à nouveau modifie sa note.
  Future<void> rateArticle(NewsItem article) async {
    final id = article.id;
    if (id == null) return;
    if (article.ownerKey == widget.accountKey) {
      context.showMessage(
        'C’est votre actualité : vous ne pouvez pas la noter vous-même.',
      );
      return;
    }
    final mine = myReviewOf(article);
    final input = await Navigator.push<ReviewInput>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewFormPage(
          articleTitle: article.title,
          initialStars: mine?.stars ?? 0,
          initialReview: mine?.review ?? '',
        ),
      ),
    );
    if (!mounted || input == null) return;
    try {
      await NewsFeedback.saveReview(
        articleId: id,
        articleTitle: article.title,
        ownerKey: widget.accountKey,
        stars: input.stars,
        review: input.review,
      );
      await loadItems();
      if (!mounted) return;
      context.showMessage(
        mine == null ? 'Merci pour votre note ⭐' : 'Votre note a été modifiée.',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
    }
  }

  /// Ouvre la discussion propre à cet article.
  Future<void> openDiscussion(NewsItem article) async {
    if (article.id == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ArticleDiscussionPage(
          article: article,
          accountKey: widget.accountKey,
        ),
      ),
    );
    if (mounted) await loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualités tech'),
        actions: [
          IconButton(
            tooltip: 'Ajouter une actualité',
            onPressed: addArticle,
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages actualités',
            onSelected: (value) =>
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => switch (value) {
                      'mine' => const ArticleManagementPage(),
                      'comments' => const RecordListPage(
                        title: 'Tous les commentaires',
                        collection: 'news_comments',
                        emptyMessage: 'Aucun commentaire publié.',
                      ),
                      'credibility' => const RecordListPage(
                        title: 'Scores et évaluations',
                        collection: 'news',
                        emptyMessage: 'Aucune actualité à évaluer.',
                      ),
                      _ => throw ArgumentError.value(
                        value,
                        'value',
                        'Option de menu inconnue.',
                      ),
                    },
                  ),
                ).then((_) {
                  if (mounted) loadItems();
                }),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mine',
                child: Text(
                  Permissions.isAdmin
                      ? 'Gérer tous les articles'
                      : 'Gérer mes articles',
                ),
              ),
              PopupMenuItem(
                value: 'comments',
                child: Text('Tous les commentaires'),
              ),
              PopupMenuItem(
                value: 'credibility',
                child: Text('Scores de crédibilité'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadItems)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Veille stratégique vérifiée',
                  subtitle:
                      'Actualités tech évaluées par la communauté et '
                      'notées selon leur fiabilité.',
                  icon: Icons.newspaper_rounded,
                  palette: ModulePalette.news,
                  stats: [
                    ('${items.length}', 'articles'),
                    (
                      items.isEmpty
                          ? '—'
                          : '${(items.map((item) => item.credibility).reduce((a, b) => a + b) / items.length).round()} %',
                      'fiabilité moyenne',
                    ),
                    ('${reviews.length}', 'avis'),
                  ],
                ),
                TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une actualité',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final level in TrustLevel.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Text(switch (level) {
                              TrustLevel.all => '📰',
                              TrustLevel.high => '🟢',
                              TrustLevel.medium => '🟡',
                              TrustLevel.low => '🔴',
                            }),
                            label: Text(
                              '${level.label} '
                              '(${items.where((item) => level.accepts(item.credibility)).length})',
                            ),
                            selected: trustLevel == level,
                            onSelected: (_) =>
                                setState(() => trustLevel = level),
                          ),
                        ),
                      PopupMenuButton<NewsSort>(
                        tooltip: 'Trier les actualités',
                        initialValue: newsSort,
                        onSelected: (value) => setState(() => newsSort = value),
                        itemBuilder: (_) => [
                          for (final sort in NewsSort.values)
                            PopupMenuItem(value: sort, child: Text(sort.label)),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.sort_rounded, size: 18),
                          label: Text(newsSort.label),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...searchResults.map(
                  (item) => ArticleCard(
                    item,
                    averageStars: summaryOf(item).average,
                    reviewCount: summaryOf(item).count,
                    commentCount: commentCountOf(item),
                    myStars: myReviewOf(item)?.stars,
                    onRate: () => rateArticle(item),
                    onDiscuss: () => openDiscussion(item),
                    onDetails: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RecordDetailsPage(
                          title: 'Détails de l’actualité',
                          record: item.toMap(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (searchResults.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'Aucun article trouvé.',
                    palette: ModulePalette.news,
                  ),
              ],
            ),
    );
  }
}
