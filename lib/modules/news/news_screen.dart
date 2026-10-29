import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import '../../shared/database_error_view.dart';
import '../../shared/data_record_details_page.dart';
import '../../shared/data_record_list_page.dart';
import 'news_comment_form_page.dart';
import 'news_article_form_page.dart';
import 'news_management_page.dart';

class NewsScreen extends StatefulWidget {
  final String accountKey;
  const NewsScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String query = '';
  final List<String> comments = [];
  bool loading = true;
  String? loadError;

  static const sampleItems = [
    NewsItem(
      title: 'L’IA générative transforme le développement',
      source: 'Tech Daily',
      credibility: 96,
      tag: 'IA',
      summary: 'Les assistants de code accélèrent les tâches répétitives.',
    ),
    NewsItem(
      title: 'Les startups renforcent leur sécurité par passkeys',
      source: 'Cyber Weekly',
      credibility: 92,
      tag: 'Sécurité',
      summary: 'Les entreprises migrent vers des mécanismes plus sûrs.',
    ),
    NewsItem(
      title: 'Le cloud hybride gagne du terrain',
      source: 'Cloud Lab',
      credibility: 90,
      tag: 'Cloud',
      summary: 'Les PME cherchent un équilibre coût-flexibilité.',
    ),
  ];
  final items = <NewsItem>[...sampleItems];

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
      final rows = await CrowdTechDatabase.loadSeededItems(
        'news',
        sampleItems.map((item) => item.toMap()).toList(),
      );
      final savedComments = await CrowdTechDatabase.getItems('news_comments');
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(rows.map(NewsItem.fromMap));
        comments
          ..clear()
          ..addAll(savedComments.map((comment) => comment['text']! as String));
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

  Future<void> addArticle() async {
    final article = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const NewsArticleFormPage()),
    );
    if (!mounted || article == null) return;
    try {
      final id = await CrowdTechDatabase.insertItem('news', {
        ...article,
        'credibility': 0,
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(
        () => items.insert(
          0,
          NewsItem.fromMap({
            'id': id,
            ...article,
            'credibility': 0,
            'ownerKey': widget.accountKey,
          }),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article enregistré. Fiabilité à vérifier.'),
      ),
    );
  }

  Future<void> evaluateArticle(NewsItem article) async {
    if (article.id == null || article.credibility >= 100) return;
    final updatedArticle = article.copyWithCredibility(
      (article.credibility + 1).clamp(0, 100),
    );
    try {
      final rowsUpdated = await CrowdTechDatabase.updateItem(
        'news',
        article.id!,
        updatedArticle.toMap(),
      );
      if (rowsUpdated != 1) {
        throw Exception('L’actualité à évaluer est introuvable.');
      }
      if (!mounted) return;
      setState(() {
        final index = items.indexWhere((item) => item.id == article.id);
        if (index >= 0) items[index] = updatedArticle;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
    }
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
            onSelected: (value) => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => switch (value) {
                  'mine' => const NewsManagementPage(),
                  'comments' => const DataRecordListPage(
                    title: 'Discussion des actualités',
                    collection: 'news_comments',
                    emptyMessage: 'Aucun commentaire publié.',
                  ),
                  'credibility' => const DataRecordListPage(
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
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mine',
                child: Text('Gérer tous les articles'),
              ),
              PopupMenuItem(value: 'comments', child: Text('Discussion')),
              PopupMenuItem(
                value: 'credibility',
                child: Text('Scores de crédibilité'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadItems)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Veille stratégique vérifiée',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une actualité',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: addComment,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Participer à la discussion'),
                ),
                if (comments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Commentaires modérés (${comments.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...comments.map(
                    (comment) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(comment),
                        subtitle: const Text('Publié après validation locale'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...items
                    .where(
                      (item) =>
                          item.title.toLowerCase().contains(query) ||
                          item.source.toLowerCase().contains(query) ||
                          item.tag.toLowerCase().contains(query) ||
                          item.summary.toLowerCase().contains(query),
                    )
                    .map(
                      (item) => _NewsCard(
                        item,
                        onEvaluate: () => evaluateArticle(item),
                        onDetails: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DataRecordDetailsPage(
                              title: 'Détails de l’actualité',
                              record: item.toMap(),
                            ),
                          ),
                        ),
                      ),
                    ),
                if (!items.any(
                  (item) =>
                      item.title.toLowerCase().contains(query) ||
                      item.source.toLowerCase().contains(query) ||
                      item.tag.toLowerCase().contains(query) ||
                      item.summary.toLowerCase().contains(query),
                ))
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Aucun article trouvé.')),
                  ),
              ],
            ),
    );
  }

  Future<void> addComment() async {
    final comment = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const NewsCommentFormPage()),
    );
    if (!mounted || comment == null) return;
    try {
      await CrowdTechDatabase.insertItem('news_comments', {
        'text': comment,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() => comments.insert(0, comment));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Commentaire enregistré dans la discussion.'),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onEvaluate;
  final VoidCallback onDetails;
  const _NewsCard(
    this.item, {
    required this.onEvaluate,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.tag,
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item.credibility == 0
                    ? 'À vérifier'
                    : 'Fiabilité ${item.credibility}%',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(item.summary, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Text(
            'Source : ${item.source}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Voir les détails'),
                ),
                TextButton.icon(
                  onPressed: onEvaluate,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Évaluer positivement'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
