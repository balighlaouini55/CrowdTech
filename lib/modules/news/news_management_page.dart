import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../shared/data_record_details_page.dart';
import 'news_article_form_page.dart';

class NewsManagementPage extends StatefulWidget {
  const NewsManagementPage({super.key});

  @override
  State<NewsManagementPage> createState() => _NewsManagementPageState();
}

class _NewsManagementPageState extends State<NewsManagementPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> articles = [];

  @override
  void initState() {
    super.initState();
    loadArticles();
  }

  Future<void> loadArticles() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await CrowdTechDatabase.getItems('news');
      if (!mounted) return;
      setState(() {
        articles = rows.reversed.toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les actualités : $exception';
        loading = false;
      });
    }
  }

  Future<void> editArticle(Map<String, Object?> article) async {
    final id = article['id'];
    if (id is! int) return;

    final changes = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(
        builder: (_) => NewsArticleFormPage(initialValues: article),
      ),
    );
    if (!mounted || changes == null) return;

    try {
      final rows = await CrowdTechDatabase.updateItem(
        'news',
        id,
        {...article, ...changes}..remove('id'),
      );
      if (rows != 1) throw Exception('Cet article est introuvable.');
      await loadArticles();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier l’article : $exception'),
        ),
      );
    }
  }

  Future<void> deleteArticle(Map<String, Object?> article) async {
    final id = article['id'];
    if (id is! int) return;
    final title = article['title']?.toString() ?? 'cet article';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’article ?'),
        content: Text('Voulez-vous supprimer « $title » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      final rows = await CrowdTechDatabase.deleteItem('news', id);
      if (rows != 1) throw Exception('Cet article est introuvable.');
      await loadArticles();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de supprimer l’article : $exception'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des actualités'),
        actions: [
          IconButton(
            onPressed: loadArticles,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadArticles,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : articles.isEmpty
          ? const Center(child: Text('Aucune actualité enregistrée.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                final title = article['title']?.toString() ?? 'Actualité';
                final source = article['source']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.newspaper_rounded),
                    ),
                    title: Text(title),
                    subtitle: Text(source),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataRecordDetailsPage(
                          title: title,
                          record: article,
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editArticle(article);
                        if (action == 'delete') deleteArticle(article);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
