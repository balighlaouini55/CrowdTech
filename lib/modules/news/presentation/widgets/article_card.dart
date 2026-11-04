// Carte d'une actualité dans la liste.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/info_line.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:crowdtech/shared/widgets/star_rating.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ArticleCard extends StatelessWidget {
  final NewsItem item;

  /// Moyenne des étoiles (0 si aucune note) et nombre de notes.
  final double averageStars;
  final int reviewCount;

  /// Nombre de commentaires dans la discussion de CET article.
  final int commentCount;

  /// Note déjà donnée par l'utilisateur connecté, sinon null.
  final int? myStars;
  final VoidCallback onRate;
  final VoidCallback onDiscuss;
  final VoidCallback onDetails;
  const ArticleCard(
    this.item, {
    super.key,
    this.averageStars = 0,
    this.reviewCount = 0,
    this.commentCount = 0,
    this.myStars,
    required this.onRate,
    required this.onDiscuss,
    required this.onDetails,
  });

  BadgeTone get credibilityTone => switch (item.credibility) {
    0 => BadgeTone.neutral,
    >= 90 => BadgeTone.success,
    >= 70 => BadgeTone.info,
    _ => BadgeTone.warning,
  };

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(item.url ?? '')?.host ?? '';
    final meta = [
      item.source,
      if (item.author case final author? when author.isNotEmpty) author,
      if (item.publishedAt != null) formatDate(item.publishedAt),
    ].join(' • ');
    return FadeSlideIn(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ItemImage.hasPhoto(item.imageUrl, item.imageData)) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 160,
                    child: ItemImage(
                      imageUrl: item.imageUrl,
                      imageData: item.imageData,
                      icon: Icons.newspaper_rounded,
                      colors: [
                        ModulePalette.news.start,
                        ModulePalette.news.end,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  StatusBadge(item.tag, icon: Icons.sell_outlined),
                  const Spacer(),
                  StatusBadge(
                    item.credibility == 0
                        ? 'À vérifier'
                        : 'Fiabilité ${item.credibility}%',
                    tone: credibilityTone,
                    icon: item.credibility == 0
                        ? Icons.hourglass_empty_rounded
                        : Icons.verified_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              InfoLine(Icons.feed_outlined, meta),
              if (host.isNotEmpty) InfoLine(Icons.link_rounded, host),
              const SizedBox(height: 10),
              // Note moyenne de la communauté.
              Row(
                children: [
                  StarRating(averageStars),
                  const SizedBox(width: 8),
                  Text(
                    reviewCount == 0
                        ? 'Pas encore noté'
                        : '${averageStars.toStringAsFixed(1)} · '
                              '$reviewCount avis',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Détails'),
                  ),
                  TextButton.icon(
                    onPressed: onDiscuss,
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: Text(
                      commentCount == 0
                          ? 'Discussion'
                          : 'Discussion ($commentCount)',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRate,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                    ),
                    icon: Icon(
                      myStars == null
                          ? Icons.star_outline_rounded
                          : Icons.star_rounded,
                      size: 20,
                    ),
                    label: Text(
                      myStars == null ? 'Noter' : 'Ma note : $myStars',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
