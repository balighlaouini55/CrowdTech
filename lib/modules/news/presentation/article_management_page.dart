// Gestion des actualités : modifier, supprimer, importer (HTTP).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/news/data/news_repository.dart';
import 'package:crowdtech/modules/news/data/news_web_api.dart';
import 'package:crowdtech/modules/news/presentation/article_form_page.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/utils/api_import.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/management_list_view.dart';
import 'package:crowdtech/shared/widgets/module_avatar.dart';
import 'package:flutter/material.dart';

class ArticleManagementPage extends StatefulWidget {
  const ArticleManagementPage({super.key});

  @override
  State<ArticleManagementPage> createState() => _ArticleManagementPageState();
}

class _ArticleManagementPageState extends State<ArticleManagementPage> {
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
      final rows = await NewsRepository.articles.all();
      if (!mounted) return;
      setState(() {
        // Chacun gère ses propres éléments ; l'administrateur gère tout.
        articles = rows.where(Permissions.canManage).toList().reversed.toList();
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
        builder: (_) => ArticleFormPage(initialValues: article),
      ),
    );
    if (!mounted || changes == null) return;

    try {
      final rows = await NewsRepository.articles.update(
        id,
        {...article, ...changes}..remove('id'),
      );
      if (rows != 1) throw Exception('Cet article est introuvable.');
      await loadArticles();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier l’article : $exception');
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
      final rows = await NewsRepository.articles.remove(id);
      if (rows != 1) throw Exception('Cet article est introuvable.');
      await loadArticles();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de supprimer l’article : $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des actualités'),
        actions: [
          if (Permissions.isAdmin)
            IconButton(
              onPressed: () => runApiImport(
                context,
                run: () async => NewsRepository.articles.import(
                  await CrowdTechApi.fetchTechNews(),
                  uniqueKey: 'title',
                ),
                reload: loadArticles,
                successLabel: 'actualité(s) importée(s) depuis Hacker News',
              ),
              tooltip: 'Importer depuis Internet',
              icon: const Icon(Icons.cloud_download_rounded),
            ),
          if (Permissions.isAdmin)
            IconButton(
              onPressed: () => runApiImport(
                context,
                run: () async => NewsRepository.articles.import(
                  await NewsWebApi.fetchDevTo(),
                  uniqueKey: 'title',
                ),
                reload: loadArticles,
                successLabel: 'actualité(s) importée(s) depuis DEV Community',
              ),
              tooltip: 'Importer depuis DEV Community',
              icon: const Icon(Icons.library_add_rounded),
            ),
          IconButton(
            onPressed: loadArticles,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
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
          ? const EmptyState(
              palette: ModulePalette.news,
              icon: Icons.newspaper_outlined,
              message: 'Aucune actualité enregistrée.',
            )
          : ManagementListView(
              records: articles,
              noun: 'actualité',
              searchKeys: const ['title', 'source', 'tag', 'author'],
              itemBuilder: (context, article) {
                final title = article['title']?.toString() ?? 'Actualité';
                final credibility = (article['credibility'] as num?) ?? 0;
                final subtitle = [
                  article['tag'],
                  article['source'],
                  if (article['publishedAt'] case final String date)
                    formatDate(date),
                  credibility == 0 ? 'À vérifier' : 'Fiabilité $credibility %',
                ].whereType<String>().join(' • ');
                return Card(
                  child: ListTile(
                    leading: const ModuleAvatar(
                      Icons.newspaper_rounded,
                      palette: ModulePalette.news,
                    ),
                    title: Text(title),
                    subtitle: Text(subtitle),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecordDetailsPage(title: title, record: article),
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
