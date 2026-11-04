// Carte d'un projet dans la liste : visuel, statut, montant levé et
// progression mis en avant, puis informations clés et actions.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/gradient_progress_bar.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ProjectCard extends StatelessWidget {
  final FundingProject project;
  final VoidCallback onInvest;
  final VoidCallback onDetails;

  /// Nombre de personnes qui ont déjà investi.
  final int supporters;

  /// Position dans la liste (pour décaler l'animation d'apparition).
  final int index;

  /// Projet suivi par l'utilisateur (❤️).
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  const ProjectCard(
    this.project, {
    super.key,
    required this.onInvest,
    required this.onDetails,
    this.supporters = 0,
    this.index = 0,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  BadgeTone get statusTone => switch (project.statusLabel) {
    'Financé' => BadgeTone.success,
    'En cours' => BadgeTone.info,
    'En attente de validation' => BadgeTone.warning,
    _ => BadgeTone.danger,
  };

  @override
  Widget build(BuildContext context) {
    final daysLeft = project.daysLeft;
    final hasPhoto = ItemImage.hasPhoto(project.imageUrl, project.imageData);
    final accent = project.isFunded
        ? AppColors.success
        : AppColors.primaryBright;
    return FadeSlideIn(
      index: index,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto) _banner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!hasPhoto)
                        StatusBadge(project.statusLabel, tone: statusTone),
                      if (project.category case final category?)
                        StatusBadge(category, icon: Icons.category_outlined),
                      if (project.stage case final stage?)
                        StatusBadge(
                          stage,
                          tone: BadgeTone.neutral,
                          icon: Icons.timeline_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.title, style: AppText.title),
                            const SizedBox(height: 2),
                            Text(
                              'Par ${project.company}',
                              style: AppText.caption.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (!hasPhoto && onToggleFavorite != null)
                        _favoriteButton(),
                    ],
                  ),
                  if (!project.isApproved || project.refunded) ...[
                    const SizedBox(height: AppSpacing.md),
                    _notice(),
                  ],
                  if (project.description case final description?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Bloc financier : montant levé, progression, objectif.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md + 2),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                '${formatMoney(project.amountRaised)} levés',
                                style: AppText.figure.copyWith(fontSize: 17),
                              ),
                            ),
                            Text(
                              '${project.progress}%',
                              style: AppText.figure.copyWith(
                                fontSize: 15,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                        GradientProgressBar(
                          value: project.progress / 100,
                          palette: project.isFunded
                              ? ModulePalette.events
                              : ModulePalette.funding,
                          height: 6,
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Objectif ${formatMoney(project.goal)}',
                                style: AppText.caption,
                              ),
                            ),
                            if (daysLeft != null &&
                                !project.isClosed &&
                                !project.isFunded)
                              Text(
                                daysLeft == 0 ? 'Dernier jour' : 'J-$daysLeft',
                                style: AppText.caption.copyWith(
                                  color: daysLeft <= 7
                                      ? AppColors.warning
                                      : AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (project.deadline != null)
                              Text(
                                'Fin : ${formatDate(project.deadline)}',
                                style: AppText.caption,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Informations clés en trois colonnes.
                  Row(
                    children: [
                      _fact(
                        Icons.toll_outlined,
                        formatMoney(project.tokenPrice),
                        'le jeton',
                      ),
                      _fact(
                        Icons.groups_outlined,
                        '$supporters',
                        supporters <= 1 ? 'contributeur' : 'contributeurs',
                      ),
                      _fact(
                        Icons.place_outlined,
                        project.location ?? '—',
                        project.teamSize == null
                            ? 'lieu'
                            : 'équipe de ${project.teamSize}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 16,
                        color: AppColors.primaryBright,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Fonctionnalité financée : ${project.feature}',
                          style: AppText.caption.copyWith(
                            color: AppColors.ink,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDetails,
                          child: const Text('Détails'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: project.acceptsInvestments
                              ? onInvest
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            project.isFunded
                                ? 'Objectif atteint'
                                : !project.isApproved
                                ? project.statusLabel
                                : project.isClosed
                                ? 'Collecte clôturée'
                                : 'Investir',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visuel du projet en bandeau, avec le statut et le bouton « suivre ».
  Widget _banner() {
    return SizedBox(
      height: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ItemImage(
            imageUrl: project.imageUrl,
            imageData: project.imageData,
            icon: Icons.rocket_launch_rounded,
            colors: [ModulePalette.funding.start, ModulePalette.funding.end],
          ),
          // Fondu vers la carte pour lier l'image au contenu.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00111725), Color(0xCC111725)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 12,
            child: StatusBadge(project.statusLabel, tone: statusTone),
          ),
          if (onToggleFavorite != null)
            Positioned(right: 8, top: 6, child: _favoriteButton(glass: true)),
        ],
      ),
    );
  }

  Widget _favoriteButton({bool glass = false}) {
    return IconButton(
      tooltip: isFavorite ? 'Ne plus suivre le projet' : 'Suivre le projet',
      onPressed: onToggleFavorite,
      style: glass
          ? IconButton.styleFrom(
              backgroundColor: AppColors.background.withValues(alpha: 0.55),
            )
          : null,
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFavorite ? AppColors.danger : AppColors.ink,
        size: 20,
      ),
    );
  }

  Widget _notice() {
    final pending = project.approval == ProjectApproval.pending;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: pending ? AppColors.warningSoft : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (pending ? AppColors.warning : AppColors.danger).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Text(
        pending
            ? '⏳ Visible seulement par vous et l’administrateur '
                  'jusqu’à sa validation.'
            : project.approval == ProjectApproval.rejected
            ? '❌ Refusé : ${project.rejectionReason ?? 'sans motif'}'
            : '↩️ Objectif non atteint à la date limite : les '
                  'investisseurs ont été remboursés.',
        style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 13),
      ),
    );
  }

  Widget _fact(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
