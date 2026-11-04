// Gestion des projets : modifier, supprimer, importer (HTTP).

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/presentation/project_form_page.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/utils/api_import.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/management_list_view.dart';
import 'package:crowdtech/shared/widgets/module_avatar.dart';
import 'package:flutter/material.dart';

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
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
      final rows = await FundingRepository.projects.all();
      if (!mounted) return;
      setState(() {
        // Chacun gère ses propres éléments ; l'administrateur gère tout.
        projects = rows.where(Permissions.canManage).toList().reversed.toList();
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
        builder: (_) => ProjectFormPage(initialValues: project),
      ),
    );
    if (!mounted || changes == null) return;

    try {
      final values = {...project, ...changes}..remove('id');
      // Un projet refusé et corrigé par son porteur repart en validation.
      if (!Permissions.isAdmin &&
          values['approval'] == ProjectApproval.rejected) {
        values
          ..['approval'] = ProjectApproval.pending
          ..remove('rejectionReason');
      }
      final goal = (values['goal']! as num).toDouble();
      final raised = (values['amountRaised']! as num).toDouble();
      values['progress'] = (raised / goal * 100).round().clamp(0, 100);
      final rows = await FundingRepository.projects.update(id, values);
      if (rows != 1) throw Exception('Ce projet est introuvable.');
      await loadProjects();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier le projet : $exception');
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
      final rows = await FundingRepository.projects.remove(id);
      if (rows != 1) throw Exception('Ce projet est introuvable.');
      await loadProjects();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de supprimer le projet : $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des projets'),
        actions: [
          if (Permissions.isAdmin)
            IconButton(
              onPressed: () => runApiImport(
                context,
                run: () async => FundingRepository.projects.import(
                  await CrowdTechApi.fetchFundingProjects(),
                  uniqueKey: 'title',
                ),
                reload: loadProjects,
                successLabel: 'projet(s) importé(s) depuis GitHub',
              ),
              tooltip: 'Importer depuis Internet',
              icon: const Icon(Icons.cloud_download_rounded),
            ),
          IconButton(
            onPressed: loadProjects,
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
                      onPressed: loadProjects,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : projects.isEmpty
          ? const EmptyState(
              icon: Icons.rocket_launch_outlined,
              message: 'Aucun projet enregistré.',
            )
          : ManagementListView(
              records: projects,
              noun: 'projet',
              searchKeys: const ['title', 'company', 'category', 'feature'],
              itemBuilder: (context, project) {
                final title = project['title']?.toString() ?? 'Projet';
                final company = project['company']?.toString() ?? '';
                final raised =
                    (project['amountRaised'] as num?)?.toDouble() ?? 0;
                final goal = (project['goal'] as num?)?.toDouble() ?? 0;
                final deadline = project['deadline']?.toString();
                return Card(
                  child: ListTile(
                    leading: const ModuleAvatar(Icons.trending_up_rounded),
                    title: Text(title),
                    subtitle: Text(
                      [
                        company,
                        ?project['category']?.toString(),
                        '${formatMoney(raised)} / ${formatMoney(goal)}',
                        if (deadline != null) 'fin ${formatDate(deadline)}',
                      ].join(' • '),
                    ),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecordDetailsPage(title: title, record: project),
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
