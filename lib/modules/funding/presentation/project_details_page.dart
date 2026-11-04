// Page d'un projet : progression, chiffres clés, description, derniers
// soutiens et bouton « Investir ». Renvoie true si l'utilisateur veut investir.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/presentation/project_features_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_milestones_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_questions_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_updates_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_converter_page.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/gradient_button.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ProjectDetailsPage extends StatelessWidget {
  final FundingProject project;

  /// Investissements déjà faits dans ce projet (du plus récent au plus ancien).
  final List<Map<String, Object?>> investments;

  /// Compte connecté (pour les contreparties et l'espace du projet).
  final String accountKey;

  const ProjectDetailsPage({
    required this.project,
    required this.investments,
    this.accountKey = '',
    super.key,
  });

  int get supporters =>
      investments.map((investment) => investment['ownerKey']).toSet().length;

  int get tokensSold => investments.fold(
    0,
    (sum, investment) => sum + ((investment['tokens'] as num?)?.toInt() ?? 0),
  );

  static void _open(BuildContext context, Widget page) => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => page),
  );

  /// Montant que l'utilisateur connecté a investi dans ce projet.
  double get myAmount => CrowdRules.sumAmount(
    investments.where((row) => row['ownerKey'] == accountKey),
  );

  /// Contreparties : paliers atteints selon le montant investi.
  Widget _rewardsPanel() {
    final mine = CrowdRules.tierFor(myAmount);
    final next = CrowdRules.nextTier(myAmount);
    return _Panel(
      title: 'Contreparties',
      icon: Icons.card_giftcard_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in CrowdRules.rewardTiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(tier.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tier.name} — dès ${formatMoney(tier.minAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          tier.perk,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (myAmount >= tier.minAmount)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                ],
              ),
            ),
          Text(
            mine == null
                ? next == null
                      ? ''
                      : 'Investissez ${formatMoney(next.minAmount)} pour '
                            'devenir ${next.name} ${next.emoji}'
                : 'Vous êtes ${mine.name} ${mine.emoji}'
                      '${next == null ? ' : palier maximum atteint !' : ' • encore ${formatMoney(next.minAmount - myAmount)} pour ${next.name}'}',
            style: TextStyle(
              color: ModulePalette.funding.start,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canInvest = project.acceptsInvestments;
    final daysLeft = project.daysLeft;
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du projet')),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: softShadow,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: GradientButton(
              onPressed: canInvest ? () => Navigator.pop(context, true) : null,
              icon: Icons.shopping_bag_rounded,
              label: project.isFunded
                  ? 'Objectif atteint 🎉'
                  : !project.isApproved
                  ? project.statusLabel
                  : project.isClosed
                  ? 'Collecte clôturée'
                  : 'Investir dans ce projet',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (ItemImage.hasPhoto(project.imageUrl, project.imageData))
            Container(
              height: 220,
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: softShadow,
              ),
              child: ItemImage(
                imageUrl: project.imageUrl,
                imageData: project.imageData,
                icon: Icons.rocket_launch_rounded,
                colors: [
                  ModulePalette.funding.start,
                  ModulePalette.funding.end,
                ],
              ),
            ),
          _Hero(project: project),
          // Progression et chiffres clés
          _Panel(
            child: Row(
              children: [
                _ProgressRing(value: project.progress / 100),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMoney(project.amountRaised),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'collectés sur ${formatMoney(project.goal)}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reste ${formatMoney((project.goal - project.amountRaised).clamp(0, project.goal))}',
                        style: TextStyle(
                          color: ModulePalette.funding.start,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _Stat(
                icon: Icons.groups_rounded,
                value: '$supporters',
                label: 'contributeurs',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.toll_rounded,
                value: '$tokensSold',
                label: 'jetons vendus',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.timer_outlined,
                value: daysLeft == null
                    ? '—'
                    : project.isClosed
                    ? 'Fini'
                    : 'J-$daysLeft',
                label: 'restants',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Le projet',
            icon: Icons.lightbulb_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.description case final description?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      description,
                      style: const TextStyle(color: AppColors.ink, height: 1.5),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ModulePalette.funding.soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: ModulePalette.funding.start,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fonctionnalité financée : ${project.feature}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Panel(
            title: 'Conditions',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _Line('Prix du jeton', formatMoney(project.tokenPrice)),
                _Line('Porteur du projet', project.company),
                if (project.stage case final stage?) _Line('Stade', stage),
                if (project.location case final location?)
                  _Line('Ville', location),
                if (project.teamSize case final size?)
                  _Line('Équipe', '$size personne(s)'),
                if (project.website case final website?)
                  _Line('Site web', Uri.tryParse(website)?.host ?? website),
                if (project.deadline != null)
                  _Line('Fin de la collecte', formatDate(project.deadline)),
                const _Line(
                  'Règle',
                  'Tout ou rien : remboursé si l’objectif n’est pas atteint',
                ),
              ],
            ),
          ),
          _rewardsPanel(),
          if (project.id != null)
            _Panel(
              title: 'Espace du projet',
              icon: Icons.forum_outlined,
              child: Column(
                children: [
                  _HubLink(
                    icon: Icons.lock_open_rounded,
                    title: 'Fonctionnalités à débloquer',
                    subtitle: 'Chaque palier de jetons débloque une étape',
                    onTap: () => _open(
                      context,
                      ProjectFeaturesPage(
                        project: project,
                        accountKey: accountKey,
                      ),
                    ),
                  ),
                  _HubLink(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Prix du jeton en devises',
                    subtitle: 'EUR, TND, USD… et jetons pour votre budget',
                    onTap: () =>
                        _open(context, TokenConverterPage(project: project)),
                  ),
                  _HubLink(
                    icon: Icons.campaign_outlined,
                    title: 'Actualités du projet',
                    subtitle: 'Les nouvelles publiées par le porteur',
                    onTap: () => _open(
                      context,
                      ProjectUpdatesPage(
                        project: project,
                        accountKey: accountKey,
                      ),
                    ),
                  ),
                  _HubLink(
                    icon: Icons.help_outline_rounded,
                    title: 'Questions-réponses',
                    subtitle: 'Posez vos questions au porteur',
                    onTap: () => _open(
                      context,
                      ProjectQuestionsPage(
                        project: project,
                        accountKey: accountKey,
                      ),
                    ),
                  ),
                  _HubLink(
                    icon: Icons.how_to_vote_outlined,
                    title: 'Jalons et votes',
                    subtitle: 'Déblocage des fonds étape par étape',
                    onTap: () => _open(
                      context,
                      ProjectMilestonesPage(
                        project: project,
                        accountKey: accountKey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _Panel(
            title: 'Derniers soutiens',
            icon: Icons.favorite_outline_rounded,
            child: investments.isEmpty
                ? const Text(
                    'Soyez le premier à soutenir ce projet !',
                    style: TextStyle(color: AppColors.muted),
                  )
                : Column(
                    children: [
                      for (final investment in investments.take(5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: ModulePalette.funding.soft,
                            child: Icon(
                              Icons.favorite_rounded,
                              color: ModulePalette.funding.start,
                              size: 20,
                            ),
                          ),
                          title: Text('Pack ${investment['pack'] ?? ''}'),
                          subtitle: Text(
                            formatDateTime(investment['createdAt']?.toString()),
                          ),
                          trailing: StatusBadge(
                            '${investment['tokens']} jetons',
                            icon: Icons.toll_rounded,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final FundingProject project;
  const _Hero({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(
        borderColor: ModulePalette.funding.start.withValues(alpha: 0.35),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ModulePalette.funding.glow),
            ),
          ),
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 150,
              color: ModulePalette.funding.start.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (project.category case final category?)
                      _HeroChip(Icons.sell_rounded, category),
                    _HeroChip(
                      Icons.flag_rounded,
                      project.isFunded
                          ? 'Financé'
                          : project.isClosed
                          ? 'Clôturé'
                          : 'En cours',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'par ${project.company}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Anneau de progression animé avec le pourcentage au centre.
class _ProgressRing extends StatelessWidget {
  final double value;
  const _ProgressRing({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: animated,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              color: ModulePalette.funding.start,
              backgroundColor: ModulePalette.funding.soft,
            ),
            Center(
              child: Text(
                '${(animated * 100).round()}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: softShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: ModulePalette.funding.start),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  const _Panel({required this.child, this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, color: ModulePalette.funding.start, size: 20),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lien vers une page de l'espace du projet.
class _HubLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Material transparent : l'effet du toucher reste visible sur le panneau.
    return Material(type: MaterialType.transparency, child: _tile());
  }

  Widget _tile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ModulePalette.funding.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: ModulePalette.funding.start, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
