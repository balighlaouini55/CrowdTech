import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import '../../shared/database_error_view.dart';
import '../../shared/data_record_list_page.dart';
import '../../shared/data_record_details_page.dart';
import '../../shared/simulation_pages.dart';
import 'funding_management_page.dart';
import 'funding_investment_form_page.dart';
import 'funding_project_form_page.dart';

class FundingScreen extends StatefulWidget {
  final String accountKey;
  const FundingScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen> {
  final raisedAmounts = <double>[];
  bool loading = true;
  String? loadError;

  static const sampleProjects = [
    FundingProject(
      title: 'AI Ops Dashboard',
      company: 'NovaStack',
      amountRaised: 42000,
      goal: 80000,
      tokenPrice: 45,
      progress: 52,
      feature: 'Supprimer les tâches répétitives',
    ),
    FundingProject(
      title: 'Green Pulse Sensor',
      company: 'EcoByte',
      amountRaised: 65000,
      goal: 95000,
      tokenPrice: 30,
      progress: 68,
      feature: 'Analyse des données environnementales',
    ),
  ];
  final projects = <FundingProject>[];

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
      final rows = await CrowdTechDatabase.loadSeededItems(
        'funding',
        sampleProjects.map((project) => project.toMap()).toList(),
      );
      if (!mounted) return;
      final loadedProjects = rows.map(FundingProject.fromMap).toList();
      setState(() {
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
      MaterialPageRoute(builder: (_) => const FundingProjectFormPage()),
    );
    if (!mounted || values == null) return;
    final project = FundingProject.fromMap({
      ...values,
      'amountRaised': 0.0,
      'progress': 0,
      'ownerKey': widget.accountKey,
    });
    try {
      final id = await CrowdTechDatabase.insertItem('funding', {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Projet enregistré dans la base locale.')),
    );
  }

  Future<void> invest(int index) async {
    final project = projects[index];
    final remainingTokens =
        ((project.goal - raisedAmounts[index]) / project.tokenPrice).floor();
    final tokens = await Navigator.push<int>(
      context,
      MaterialPageRoute<int>(
        builder: (_) => FundingInvestmentFormPage(
          projectTitle: project.title,
          maxTokens: remainingTokens,
        ),
      ),
    );
    if (!mounted || tokens == null) return;
    final investedAmount = tokens * project.tokenPrice;
    final updatedProject = project.copyWithRaised(
      (raisedAmounts[index] + investedAmount).clamp(0, project.goal).toDouble(),
    );
    try {
      final investmentId = await CrowdTechDatabase.saveInvestment(
        projectId: project.id!,
        updatedProject: updatedProject.toMap(),
        investment: {
          'projectId': project.id,
          'projectTitle': project.title,
          'tokens': tokens,
          'amount': investedAmount,
          'ownerKey': widget.accountKey,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      if (investmentId == 0) {
        throw Exception('Le projet à mettre à jour est introuvable.');
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    if (!mounted) return;
    setState(() {
      projects[index] = updatedProject;
      raisedAmounts[index] = updatedProject.amountRaised;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Investissement de $tokens jeton(s) enregistré en mode démo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowdfunding'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un projet',
            onPressed: addProject,
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages crowdfunding',
            onSelected: (value) => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => switch (value) {
                  'mine' => const FundingManagementPage(),
                  'wallet' => DataRecordListPage(
                    title: 'Portefeuille et jetons',
                    collection: 'investments',
                    emptyMessage: 'Aucun jeton investi pour le moment.',
                    ownedOnly: true,
                    accountKey: widget.accountKey,
                  ),
                  'roi' => const RoiSimulatorPage(),
                  _ => DataRecordListPage(
                    title: 'Mes investissements',
                    collection: 'investments',
                    emptyMessage: 'Aucun investissement enregistré.',
                    ownedOnly: true,
                    accountKey: widget.accountKey,
                  ),
                },
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mine',
                child: Text('Gérer tous les projets'),
              ),
              PopupMenuItem(value: 'wallet', child: Text('Portefeuille')),
              PopupMenuItem(
                value: 'roi',
                child: Text('Simulateur de rendement'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProjects)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Projets à financer',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ...projects.indexed.map(
                  (entry) => _FundingCard(
                    entry.$2.copyWithRaised(raisedAmounts[entry.$1]),
                    onInvest: () => invest(entry.$1),
                    onDetails: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataRecordDetailsPage(
                          title: 'Détails du projet',
                          record: entry.$2.toMap(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FundingCard extends StatelessWidget {
  final FundingProject project;
  final VoidCallback onInvest;
  final VoidCallback onDetails;
  const _FundingCard(
    this.project, {
    required this.onInvest,
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
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${project.progress}%',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Par ${project.company}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: project.progress / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${project.amountRaised.toStringAsFixed(0)} € levés'),
              Text('Objectif ${project.goal.toStringAsFixed(0)} €'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Feature : ${project.feature}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jeton : ${project.tokenPrice} €'),
              TextButton(onPressed: onDetails, child: const Text('Détails')),
              FilledButton(
                onPressed: project.amountRaised >= project.goal
                    ? null
                    : onInvest,
                child: Text(
                  project.amountRaised >= project.goal
                      ? 'Objectif atteint'
                      : 'Investir',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
