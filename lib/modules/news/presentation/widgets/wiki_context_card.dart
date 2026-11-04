// Carte « Vérifier sur Wikipédia » d'une actualité : résumé encyclopédique
// du sujet, pour recouper l'information avant de la noter.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/news/data/news_web_api.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WikiContextCard extends StatefulWidget {
  final String title;
  final String? tag;
  const WikiContextCard({required this.title, this.tag, super.key});

  @override
  State<WikiContextCard> createState() => _WikiContextCardState();
}

class _WikiContextCardState extends State<WikiContextCard> {
  bool loading = false;
  bool searched = false;
  WikiSummary? summary;
  String? error;

  Future<void> search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      summary = await NewsWebApi.factCheck(widget.title, tag: widget.tag);
    } on ApiException catch (exception) {
      error = 'Wikipédia indisponible : $exception';
    }
    if (mounted) {
      setState(() {
        loading = false;
        searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = summary;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: ModulePalette.news.start),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vérifier sur Wikipédia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!searched || error != null)
                  FilledButton.tonal(
                    onPressed: loading ? null : search,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Chercher'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (!searched)
              const Text(
                'Recoupez l’information avec l’encyclopédie avant de noter.',
                style: TextStyle(color: AppColors.muted),
              )
            else if (error != null)
              Text(error!, style: const TextStyle(color: AppColors.danger))
            else if (found == null)
              const Text(
                'Aucune page Wikipédia sur ce sujet : soyez prudent, '
                'l’information est peut-être trop récente ou inventée.',
                style: TextStyle(color: AppColors.warning),
              )
            else ...[
              Text(
                found.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(found.extract, maxLines: 6, overflow: TextOverflow.ellipsis),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: found.url));
                    if (!context.mounted) return;
                    context.showMessage('Lien Wikipédia copié.');
                  },
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Copier le lien'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
