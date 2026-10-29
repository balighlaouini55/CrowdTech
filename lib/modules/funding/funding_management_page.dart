import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../shared/data_record_details_page.dart';
import 'funding_project_form_page.dart';

class FundingManagementPage extends StatefulWidget {
  const FundingManagementPage({super.key});

  @override
  State<FundingManagementPage> createState() => _FundingManagementPageState();
}

class _FundingManagementPageState extends State<FundingManagementPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> projects = [];

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await CrowdTechDatabase.getItems('funding');
      if (!mounted) return;
      setState(() {
        projects = rows.reversed.toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les projets : $exception';
        loading = false;
      });
    }
  }

  Future<void> editProject(Map<String, Object?> project) async {
    final id = project['id'];
    if (id is! int) return;

    final changes = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(
        builder: (_) => FundingProjectFormPage(initialValues: project),
      ),
    );
    if (!mounted || changes == null) return;

    try {
      final values = {...project, ...changes}..remove('id');
      final goal = (values['goal']! as num).toDouble();
      final raised = (values['amountRaised']! as num).toDouble();
      values['progress'] = (raised / goal * 100).round().clamp(0, 100);
      final rows = await CrowdTechDatabase.updateItem('funding', id, values);
      if (rows != 1) throw Exception('Ce projet est introuvable.');
      await loadProjects();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier le projet : $exception'),
        ),
      );
    }
  }

  Future<void> deleteProject(Map<String, Object?> project) async {
    final id = project['id'];
    if (id is! int) return;
    final title = project['title']?.toString() ?? 'ce projet';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet ?'),
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
      final rows = await CrowdTechDatabase.deleteItem('funding', id);
      if (rows != 1) throw Exception('Ce projet est introuvable.');
      await loadProjects();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de supprimer le projet : $exception'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des projets'),
        actions: [
          IconButton(
            onPressed: loadProjects,
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
                      onPressed: loadProjects,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : projects.isEmpty
          ? const Center(child: Text('Aucun projet enregistré.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final title = project['title']?.toString() ?? 'Projet';
                final company = project['company']?.toString() ?? '';
                final raised =
                    (project['amountRaised'] as num?)?.toDouble() ?? 0;
                final goal = (project['goal'] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.trending_up_rounded),
                    ),
                    title: Text(title),
                    subtitle: Text(
                      '$company • ${raised.toStringAsFixed(2)} € / ${goal.toStringAsFixed(2)} €',
                    ),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataRecordDetailsPage(
                          title: title,
                          record: project,
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editProject(project);
                        if (action == 'delete') deleteProject(project);
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
