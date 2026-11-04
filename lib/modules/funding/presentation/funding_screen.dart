// Écran Crowdfunding : liste des projets et achat de packs de jetons.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/data/sample_projects.dart';
import 'package:crowdtech/modules/funding/domain/crowd_assistant.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/modules/funding/presentation/crowd_assistant_page.dart';
import 'package:crowdtech/modules/funding/presentation/investor_profile_page.dart';
import 'package:crowdtech/modules/funding/presentation/owner_dashboard_page.dart';
import 'package:crowdtech/modules/funding/presentation/pack_purchase_page.dart';
import 'package:crowdtech/modules/funding/presentation/portfolio_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_details_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_form_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_management_page.dart';
import 'package:crowdtech/modules/funding/presentation/project_review_page.dart';
import 'package:crowdtech/modules/funding/presentation/referral_page.dart';
import 'package:crowdtech/modules/funding/presentation/roi_simulator_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_market_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_pack_management_page.dart';
import 'package:crowdtech/modules/funding/presentation/widgets/project_card.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/reload_on_sync.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class FundingScreen extends StatefulWidget {
  final String accountKey;
  const FundingScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen>
    with ReloadOnSync<FundingScreen> {
  @override
  void reloadAfterSync() => loadProjects();

  final raisedAmounts = <double>[];
  bool loading = true;
  String? loadError;

  final projects = <FundingProject>[];

  /// Tous les investissements (pour compter les contributeurs de chaque projet).
  List<Map<String, Object?>> investments = [];

  /// Projets suivis (❤️) et projets en attente de validation (admin).
  Set<int> favorites = {};
  int pendingCount = 0;
  bool onlyFavorites = false;

  // Filtres de la liste
  String query = '';
  String? categoryFilter;
  String sort = 'featured';
  static const sorts = {
    'featured': 'À la une',
    'funded': 'Les plus financés',
    'ending': 'Fin proche',
  };

  List<Map<String, Object?>> investmentsOf(FundingProject project) =>
      investments.where((row) => row['projectId'] == project.id).toList();

  int supportersOf(FundingProject project) =>
      investmentsOf(project).map((row) => row['ownerKey']).toSet().length;

  List<Map<String, Object?>> get myInvestments =>
      investments.where((row) => row['ownerKey'] == widget.accountKey).toList();

  /// Index des projets à afficher, après recherche, filtre et tri.
  List<int> get visibleIndexes {
    final indexes = [
      for (final (index, project) in projects.indexed)
        if ((categoryFilter == null || project.category == categoryFilter) &&
            (!onlyFavorites || favorites.contains(project.id)) &&
            (query.isEmpty ||
                project.title.toLowerCase().contains(query) ||
                project.company.toLowerCase().contains(query) ||
                (project.category ?? '').toLowerCase().contains(query)))
          index,
    ];
    double progressOf(int i) => raisedAmounts[i] / projects[i].goal;
    int daysOf(int i) => projects[i].daysLeft ?? 1 << 30;
    switch (sort) {
      case 'funded':
        indexes.sort((a, b) => progressOf(b).compareTo(progressOf(a)));
      case 'ending':
        indexes.sort((a, b) => daysOf(a).compareTo(daysOf(b)));
    }
    return indexes;
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      await FundingRepository.projects.seeded(
        sampleProjects.map((project) => project.toMap()).toList(),
      );
      // Tout ou rien : les collectes échouées sont remboursées.
      final refundedCount = await CrowdRules.processExpiredProjects();
      final rows = await FundingRepository.projects.all();
      final loadedInvestments = await CrowdRules.activeInvestments();
      final loadedFavorites = await CrowdRules.favoriteIds(widget.accountKey);
      final pending = rows
          .map(FundingProject.fromMap)
          .where((project) => project.approval == ProjectApproval.pending)
          .length;
      if (!mounted) return;
      // Projets non validés : visibles seulement par leur porteur et l'admin.
      final loadedProjects = rows
          .map(FundingProject.fromMap)
          .where((project) => CrowdRules.isVisible(project, widget.accountKey))
          .toList();
      if (refundedCount > 0) {
        context.showMessage(
          '$refundedCount collecte(s) échouée(s) : les investisseurs ont '
          'été remboursés automatiquement.',
        );
      }
      setState(() {
        pendingCount = pending;
        favorites = loadedFavorites;
        investments = loadedInvestments.reversed.toList();
        projects
          ..clear()
          ..addAll(loadedProjects);
        raisedAmounts
          ..clear()
          ..addAll(loadedProjects.map((project) => project.amountRaised));
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger les projets : $error';
      });
    }
  }

  Future<void> addProject() async {
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectFormPage()),
    );
    if (!mounted || values == null) return;
    final project = FundingProject.fromMap({
      ...values,
      'amountRaised': 0.0,
      'progress': 0,
      'ownerKey': widget.accountKey,
      'approval': CrowdRules.approvalForNewProject,
    });
    try {
      final id = await FundingRepository.projects.add({
        ...project.toMap(),
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() {
        projects.add(project.copyWithId(id));
        raisedAmounts.add(project.amountRaised);
      });
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    context.showMessage(
      project.isApproved
          ? 'Projet enregistré dans la base locale.'
          : 'Projet envoyé : il sera visible par tous après validation '
                'par l’administrateur.',
    );
  }

  /// Suit ou ne suit plus un projet (❤️).
  Future<void> toggleFavorite(FundingProject project) async {
    final id = project.id;
    if (id == null) return;
    final followed = await CrowdRules.toggleFavorite(id, widget.accountKey);
    if (!mounted) return;
    setState(() => followed ? favorites.add(id) : favorites.remove(id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            followed
                ? 'Vous suivez « ${project.title} » ❤️'
                : 'Vous ne suivez plus « ${project.title} ».',
          ),
        ),
      );
  }

  void showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> invest(int index) async {
    final project = projects[index];
    if (!project.isApproved) {
      showMessage(
        project.approval == ProjectApproval.rejected
            ? 'Ce projet a été refusé par l’administrateur.'
            : 'Ce projet attend la validation de l’administrateur.',
      );
      return;
    }
    if (project.isClosed) {
      context.showMessage('La collecte de ce projet est clôturée.');
      return;
    }
    if (project.ownerKey != null && project.ownerKey == widget.accountKey) {
      context.showMessage(
        'C’est votre projet : vous ne pouvez pas y investir vous-même.',
      );
      return;
    }
    if (raisedAmounts[index] >= project.goal) {
      context.showMessage('Objectif atteint : ce projet est déjà financé.');
      return;
    }
    final List<TokenPack> packs;
    final double allowance;
    try {
      packs = TokenPack.sortedFromRows(
        await FundingRepository.tokenPacks.seeded(
          TokenPack.defaults.map((pack) => pack.toMap()).toList(),
        ),
      );
      // Plafond personnel par projet (selon le profil investisseur).
      allowance = await CrowdRules.remainingAllowance(
        project.id!,
        widget.accountKey,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    if (!mounted) return;
    if (allowance <= 0) {
      showMessage(
        'Vous avez atteint votre plafond d’investissement pour ce projet. '
        'Vous pouvez le modifier avec votre profil investisseur.',
      );
      return;
    }
    final pack = await Navigator.push<TokenPack>(
      context,
      MaterialPageRoute<TokenPack>(
        builder: (_) => PackPurchasePage(
          projectTitle: project.title,
          tokenPrice: project.tokenPrice,
          remainingAmount: project.goal - raisedAmounts[index],
          personalAllowance: allowance,
          packs: packs,
        ),
      ),
    );
    if (!mounted || pack == null) return;
    final PackPurchase purchase;
    try {
      purchase = await CrowdRules.buyPack(
        projectId: project.id!,
        pack: pack,
        accountKey: widget.accountKey,
      );
    } on RuleException catch (error) {
      if (!mounted) return;
      showMessage(error.message);
      return;
    } on Exception catch (error) {
      if (!mounted) return;
      showMessage('Erreur SQLite : $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      projects[index] = purchase.project;
      raisedAmounts[index] = purchase.project.amountRaised;
    });
    await loadProjects();
    if (!mounted) return;
    showMessage(purchase.summary);
  }

  Future<void> openDetails(int index) async {
    final project = projects[index].copyWithRaised(raisedAmounts[index]);
    final wantsToInvest = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(
          project: project,
          investments: investmentsOf(project),
          accountKey: widget.accountKey,
        ),
      ),
    );
    if (wantsToInvest == true && mounted) await invest(index);
  }

  Widget _projectCard(int index, int position) {
    final project = projects[index].copyWithRaised(raisedAmounts[index]);
    return ProjectCard(
      project,
      index: position,
      supporters: supportersOf(project),
      onInvest: () => invest(index),
      onDetails: () => openDetails(index),
      isFavorite: favorites.contains(project.id),
      onToggleFavorite: () => toggleFavorite(project),
    );
  }

  /// Carte bien visible qui ouvre l'assistant Crowdy.
  Widget _assistantBanner() {
    final palette = ModulePalette.funding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: openAssistant,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: palette.soft, width: 2),
              boxShadow: softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: palette.gradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🤖', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Une question ? Demandez à Crowdy',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Votre assistant IA pour choisir un projet ou un pack.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.start),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Puces de catégories et choix du tri.
  Widget _filters() {
    final categories = {
      for (final project in projects) ?project.category,
    }.toList()..sort();
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: ModulePalette.funding.soft,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          color: selected ? ModulePalette.funding.start : AppColors.ink,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('Tous', categoryFilter == null, () {
                setState(() => categoryFilter = null);
              }),
              chip('❤️ Suivis', onlyFavorites, () {
                setState(() => onlyFavorites = !onlyFavorites);
              }),
              for (final category in categories)
                chip(category, categoryFilter == category, () {
                  setState(() => categoryFilter = category);
                }),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.sort_rounded, color: AppColors.muted),
              ),
              for (final MapEntry(:key, :value) in sorts.entries)
                chip(value, sort == key, () => setState(() => sort = key)),
            ],
          ),
        ),
      ],
    );
  }

  /// Résumé du portefeuille de l'utilisateur, avec un lien vers le détail.
  Widget _portfolioTeaser() {
    final mine = myInvestments;
    final tokens = mine.fold<num>(
      0,
      (sum, row) => sum + ((row['tokens'] as num?) ?? 0),
    );
    final projectsCount = mine.map((row) => row['projectId']).toSet().length;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: ModulePalette.funding.gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
          ),
        ),
        title: Text('${tokens.toInt()} jetons dans votre portefeuille'),
        subtitle: Text('Vous soutenez $projectsCount projet(s)'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PortfolioPage(accountKey: widget.accountKey),
          ),
        ),
      ),
    );
  }

  /// Ouvre l'assistant avec les projets, les packs et mes investissements.
  Future<void> openAssistant() async {
    List<TokenPack> packs;
    InvestorProfile? profile;
    var referralBonuses = 0;
    try {
      packs = TokenPack.sortedFromRows(
        await FundingRepository.tokenPacks.seeded(
          TokenPack.defaults.map((pack) => pack.toMap()).toList(),
        ),
      );
    } on Exception {
      packs = TokenPack.defaults;
    }
    try {
      profile = await CrowdRules.profileOf(widget.accountKey);
      referralBonuses = await CrowdRules.availableBonuses(widget.accountKey);
    } on Exception {
      // Profil et parrainage facultatifs pour l'assistant.
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CrowdAssistantPage(
          accountKey: widget.accountKey,
          crowdContext: CrowdContext(
            projects: [
              for (final (index, project) in projects.indexed)
                project.copyWithRaised(raisedAmounts[index]),
            ],
            packs: packs,
            myInvestments: myInvestments,
            favoriteIds: favorites,
            investorProfile: profile?.name,
            limitPerProject:
                profile?.limitPerProject ?? CrowdRules.standardLimit,
            referralCode: CrowdRules.referralCodeFor(widget.accountKey),
            referralBonuses: referralBonuses,
          ),
        ),
      ),
    );
    // Crowdy a peut-être acheté un pack : montants à jour.
    if (mounted) await loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowdfunding'),
        actions: [
          IconButton(
            tooltip: 'Assistant Crowdy',
            onPressed: loading ? null : openAssistant,
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          if (Permissions.canPublishProjects)
            IconButton(
              tooltip: 'Ajouter un projet',
              onPressed: addProject,
              icon: const Icon(Icons.add_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages crowdfunding',
            onSelected: (value) async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => switch (value) {
                    'mine' => const ProjectManagementPage(),
                    'packs' => const TokenPackManagementPage(),
                    'roi' => const RoiSimulatorPage(),
                    'review' => const ProjectReviewPage(),
                    'dashboard' => OwnerDashboardPage(
                      accountKey: widget.accountKey,
                    ),
                    'market' => TokenMarketPage(accountKey: widget.accountKey),
                    'profile' => InvestorProfilePage(
                      accountKey: widget.accountKey,
                    ),
                    'referral' => ReferralPage(accountKey: widget.accountKey),
                    _ => PortfolioPage(accountKey: widget.accountKey),
                  },
                ),
              );
              // Les pages de gestion peuvent modifier SQLite : on recharge.
              if (mounted) await loadProjects();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mine',
                child: Text(
                  Permissions.isAdmin
                      ? 'Gérer tous les projets'
                      : 'Gérer mes projets',
                ),
              ),
              if (Permissions.isAdmin)
                PopupMenuItem(
                  value: 'packs',
                  child: Text('Gérer les packs de jetons'),
                ),
              if (Permissions.isAdmin)
                PopupMenuItem(
                  value: 'review',
                  child: Text('Projets à valider ($pendingCount)'),
                ),
              if (Permissions.canPublishProjects)
                PopupMenuItem(
                  value: 'dashboard',
                  child: Text('Tableau de bord porteur'),
                ),
              PopupMenuItem(value: 'wallet', child: Text('Mon portefeuille')),
              PopupMenuItem(value: 'market', child: Text('Marché des jetons')),
              PopupMenuItem(
                value: 'profile',
                child: Text('Mon profil investisseur'),
              ),
              PopupMenuItem(value: 'referral', child: Text('Parrainage')),
              PopupMenuItem(
                value: 'roi',
                child: Text('Simulateur de rendement'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProjects)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Projets à financer',
                  subtitle:
                      'Soutenez des projets tech en achetant des packs de '
                      'jetons avec bonus.',
                  icon: Icons.rocket_launch_rounded,
                  stats: [
                    ('${projects.length}', 'projets'),
                    (
                      formatMoney(
                        raisedAmounts.fold<double>(0, (a, b) => a + b),
                      ),
                      'collectés',
                    ),
                    (
                      '${projects.where((project) => project.isFunded).length}',
                      'financés',
                    ),
                  ],
                ),
                _assistantBanner(),
                if (myInvestments.isNotEmpty) _portfolioTeaser(),
                TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un projet, une entreprise…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                _filters(),
                const SizedBox(height: 12),
                if (visibleIndexes.isEmpty)
                  EmptyState(
                    icon: Icons.rocket_launch_outlined,
                    message: projects.isEmpty
                        ? 'Aucun projet pour le moment.'
                        : 'Aucun projet ne correspond à votre recherche.',
                  ),
                for (final (position, index) in visibleIndexes.indexed)
                  _projectCard(index, position),
              ],
            ),
    );
  }
}
