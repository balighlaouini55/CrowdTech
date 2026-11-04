// Tableau de bord : vue d'ensemble financière de l'utilisateur, construite
// uniquement avec les données réelles de la base (investissements, projets,
// événements). Aucun chiffre n'est inventé : sans investissement, le
// portefeuille invite à investir.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/modules/events/data/sample_events.dart';
import 'package:crowdtech/modules/events/domain/event_item.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/data/sample_projects.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/modules/funding/presentation/portfolio_page.dart';
import 'package:crowdtech/modules/funding/presentation/roi_simulator_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_market_page.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/reload_on_sync.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/gradient_progress_bar.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/premium_widgets.dart';
import 'package:crowdtech/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

/// Onglets de la barre de navigation (ordre de [HomePage]).
abstract final class HomeTab {
  static const dashboard = 0;
  static const news = 1;
  static const funding = 2;
  static const store = 3;
  static const events = 4;
  static const profile = 5;
}

class DashboardScreen extends StatefulWidget {
  final CrowdUser user;

  /// Ouvre un onglet de la barre de navigation ([HomeTab]).
  final ValueChanged<int> onOpenTab;

  /// Vrai quand l'onglet est affiché : les chiffres sont alors relus (un
  /// investissement a pu être fait dans l'onglet Crowd).
  final bool active;
  const DashboardScreen({
    required this.user,
    required this.onOpenTab,
    this.active = true,
    super.key,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with ReloadOnSync<DashboardScreen> {
  @override
  void reloadAfterSync() => load();

  bool loading = true;
  String? error;
  List<FundingProject> projects = [];

  /// Mes investissements actifs, du plus ancien au plus récent.
  List<Map<String, Object?>> mine = [];
  List<EventItem> upcoming = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) load();
  }

  Future<void> load() async {
    if (projects.isEmpty) setState(() => loading = true);
    try {
      await FundingRepository.projects.seeded(
        sampleProjects.map((project) => project.toMap()).toList(),
      );
      final rows = await FundingRepository.projects.all();
      final investments = await CrowdRules.activeInvestments();
      final events = await EventsRepository.events.seeded(
        sampleEvents.map((event) => event.toMap()).toList(),
      );
      if (!mounted) return;
      setState(() {
        projects = rows
            .map(FundingProject.fromMap)
            .where(
              (project) => CrowdRules.isVisible(project, widget.user.email),
            )
            .toList();
        mine = investments
            .where((row) => row['ownerKey'] == widget.user.email)
            .toList();
        upcoming =
            events
                .map(EventItem.fromMap)
                .where((event) => !event.isPast)
                .toList()
              ..sort(
                (a, b) => (parseFlexibleDate(a.date) ?? DateTime(9999))
                    .compareTo(parseFlexibleDate(b.date) ?? DateTime(9999)),
              );
        error = null;
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger le tableau de bord : $exception';
        loading = false;
      });
    }
  }

  String get greeting {
    final hour = DateTime.now().hour;
    final first = widget.user.name.trim().split(RegExp(r'\s+')).first;
    return '${hour < 18 ? 'Bonjour' : 'Bonsoir'}, $first';
  }

  void open(Widget page) => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => page),
  ).then((_) => load());

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: SafeArea(child: LoadingSkeleton()));
    }
    if (error != null) {
      return Scaffold(
        body: DatabaseErrorView(message: error!, onRetry: load),
      );
    }
    final popular = [...projects.where((project) => project.isApproved)]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final sections = <Widget>[
      _welcome(),
      _portfolioCard(),
      _quickActions(),
      _platformMetrics(),
      if (popular.isNotEmpty) ...[
        SectionHeader(
          'Projets populaires',
          actionLabel: 'Tout voir',
          onAction: () => widget.onOpenTab(HomeTab.funding),
        ),
        for (final project in popular.take(3)) _projectTile(project),
      ],
      SectionHeader(
        'Investissements récents',
        actionLabel: mine.isEmpty ? null : 'Historique',
        onAction: () => open(PortfolioPage(accountKey: widget.user.email)),
      ),
      _recentInvestments(),
      if (upcoming.isNotEmpty) ...[
        SectionHeader(
          'Prochains événements',
          actionLabel: 'Agenda',
          onAction: () => widget.onOpenTab(HomeTab.events),
        ),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (final event in upcoming.take(2))
                TransactionRow(
                  icon: Icons.event_rounded,
                  color: ModulePalette.events.start,
                  title: event.title,
                  subtitle: '${event.date} · ${event.city}',
                  amount: event.isFree ? 'Gratuit' : formatMoney(event.price!),
                  onTap: () => widget.onOpenTab(HomeTab.events),
                ),
            ],
          ),
        ),
      ],
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceRaised,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                children: [
                  for (final (index, section) in sections.indexed)
                    FadeSlideIn(index: index.clamp(0, 6), child: section),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppText.title.copyWith(fontSize: 22)),
                const SizedBox(height: 2),
                Text(
                  'Voici l’état de vos investissements.',
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => widget.onOpenTab(HomeTab.profile),
            child: UserAvatar(
              name: widget.user.name,
              email: widget.user.email,
              radius: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioCard() {
    final invested = CrowdRules.sumAmount(mine);
    final tokens = CrowdRules.sumTokens(mine);
    final supported = {for (final row in mine) row['projectId']}.length;
    final curve = [
      for (final point in PortfolioAnalytics.evolution(mine)) point.invested,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(
        borderColor: AppColors.primary.withValues(alpha: 0.35),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1A3F), Color(0xFF111A2C)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: ModulePalette.home.glow),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PORTEFEUILLE INVESTI', style: AppText.overline),
              const SizedBox(height: AppSpacing.sm),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: invested),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  formatMoney(value.roundToDouble()),
                  style: AppText.display,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mine.isEmpty
                    ? 'Aucun investissement pour l’instant.'
                    : '$tokens jetons · $supported projet(s) soutenu(s)',
                style: AppText.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (curve.length >= 2)
                SparklineChart(values: curve)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    mine.isEmpty
                        ? 'Choisissez un projet et achetez vos premiers jetons '
                              'pour suivre ici l’évolution de votre portefeuille.'
                        : 'La courbe apparaîtra dès votre deuxième jour '
                              'd’investissement.',
                    style: AppText.caption,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => widget.onOpenTab(HomeTab.funding),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Investir'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          open(PortfolioPage(accountKey: widget.user.email)),
                      icon: const Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 20,
                      ),
                      label: const Text('Portefeuille'),
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

  Widget _quickActions() {
    final actions = [
      (
        Icons.rocket_launch_outlined,
        'Projets',
        ModulePalette.funding.start,
        () => widget.onOpenTab(HomeTab.funding),
      ),
      (
        Icons.calculate_outlined,
        'Simulateur',
        AppColors.success,
        () => open(const RoiSimulatorPage()),
      ),
      (
        Icons.swap_horiz_rounded,
        'Marché jetons',
        AppColors.info,
        () => open(TokenMarketPage(accountKey: widget.user.email)),
      ),
      (
        Icons.storefront_outlined,
        'Store',
        ModulePalette.store.start,
        () => widget.onOpenTab(HomeTab.store),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        children: [
          for (final (icon, label, color, onTap) in actions)
            Expanded(
              child: QuickAction(
                icon: icon,
                label: label,
                color: color,
                onTap: onTap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _platformMetrics() {
    final approved = projects.where((project) => project.isApproved).toList();
    final raised = approved.fold<double>(
      0,
      (sum, project) => sum + project.amountRaised,
    );
    final open = approved.where((project) => project.acceptsInvestments).length;
    final funded = approved.where((project) => project.isFunded).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Builder(
        builder: (context) {
          final tiles = [
            MetricTile(
              label: 'Collectés',
              value: formatMoney(raised),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.success,
            ),
            MetricTile(
              label: 'Ouverts',
              value: '$open',
              icon: Icons.trending_up_rounded,
              color: AppColors.primaryBright,
            ),
            MetricTile(
              label: 'Financés',
              value: '$funded',
              icon: Icons.verified_outlined,
              color: AppColors.warning,
            ),
          ];
          return Row(
            children: [
              for (final (index, tile) in tiles.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: tile),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _projectTile(FundingProject project) {
    final palette = ModulePalette.funding;
    return SurfaceCard(
      onTap: () => widget.onOpenTab(HomeTab.funding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle,
                    ),
                    Text(
                      '${project.company} · ${project.category ?? 'Tech'}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '${project.progress.clamp(0, 999)} %',
                style: AppText.figure.copyWith(
                  fontSize: 16,
                  color: project.isFunded
                      ? AppColors.success
                      : AppColors.primaryBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GradientProgressBar(
            value: project.progress / 100,
            palette: palette,
            height: 6,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatMoney(project.amountRaised)} sur '
            '${formatMoney(project.goal)} · jeton à '
            '${formatMoney(project.tokenPrice)}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _recentInvestments() {
    if (mine.isEmpty) {
      return SurfaceCard(
        child: Row(
          children: [
            const Icon(Icons.savings_outlined, color: AppColors.muted),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Vos achats de jetons apparaîtront ici.',
                style: AppText.caption,
              ),
            ),
            TextButton(
              onPressed: () => widget.onOpenTab(HomeTab.funding),
              child: const Text('Découvrir'),
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (final row in mine.reversed.take(4))
            TransactionRow(
              icon: Icons.token_outlined,
              color: AppColors.success,
              title: '${row['projectTitle'] ?? 'Projet'}',
              subtitle:
                  '${row['tokens'] ?? 0} jetons · '
                  '${formatDate(row['createdAt']?.toString())}',
              amount: formatMoney((row['amount'] as num?) ?? 0),
            ),
        ],
      ),
    );
  }
}
