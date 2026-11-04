// Administration : projets en attente de validation (approuver / refuser).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/access_denied_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/info_line.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class ProjectReviewPage extends StatefulWidget {
  const ProjectReviewPage({super.key});

  @override
  State<ProjectReviewPage> createState() => _ProjectReviewPageState();
}

class _ProjectReviewPageState extends State<ProjectReviewPage> {
  bool loading = true;
  List<FundingProject> pending = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await FundingRepository.projects.all();
    if (!mounted) return;
    setState(() {
      pending = rows
          .map(FundingProject.fromMap)
          .where((project) => project.approval == ProjectApproval.pending)
          .toList();
      loading = false;
    });
  }

  Future<void> review(FundingProject project, {required bool approve}) async {
    var reason = '';
    if (!approve) {
      final values = await showInputDialog(
        context,
        title: 'Refuser le projet ?',
        confirmLabel: 'Refuser',
        fields: const [
          DialogField(
            'Motif du refus',
            hint: 'Ex. : informations insuffisantes sur l’équipe',
            multiline: true,
          ),
        ],
      );
      if (values == null) return;
      reason = values.single;
    }
    try {
      await CrowdRules.reviewProject(
        project.id!,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      context.showMessage(
        approve
            ? '« ${project.title} » est maintenant visible par tous ✅'
            : '« ${project.title} » a été refusé.',
      );
      await load();
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projets à valider')),
        body: const AccessDeniedView(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Projets à valider')),
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Modération des projets',
                  subtitle:
                      'Vérifiez chaque projet avant qu’il soit visible par les '
                      'investisseurs.',
                  icon: Icons.verified_user_rounded,
                  stats: [('${pending.length}', 'en attente')],
                ),
                if (pending.isEmpty)
                  const EmptyState(
                    icon: Icons.task_alt_rounded,
                    message: 'Aucun projet en attente. Tout est à jour !',
                  ),
                for (final project in pending)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Par ${project.company} • ${project.ownerKey ?? ''}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          if (project.description case final text?) ...[
                            const SizedBox(height: 8),
                            Text(text, style: const TextStyle(height: 1.4)),
                          ],
                          const SizedBox(height: 8),
                          InfoLine(
                            Icons.flag_outlined,
                            'Objectif ${formatMoney(project.goal)} • jeton '
                            '${formatMoney(project.tokenPrice)}',
                          ),
                          if (project.deadline != null)
                            InfoLine(
                              Icons.event_outlined,
                              'Fin de collecte : ${formatDate(project.deadline)}',
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      review(project, approve: false),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Refuser'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      review(project, approve: true),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Valider'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
