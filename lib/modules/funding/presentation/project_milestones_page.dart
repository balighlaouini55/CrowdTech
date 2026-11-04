// Jalons d'un projet : les fonds sont débloqués étape par étape, après un
// vote des investisseurs.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ProjectMilestonesPage extends StatefulWidget {
  final FundingProject project;
  final String accountKey;
  const ProjectMilestonesPage({
    required this.project,
    required this.accountKey,
    super.key,
  });

  @override
  State<ProjectMilestonesPage> createState() => _ProjectMilestonesPageState();
}

class _ProjectMilestonesPageState extends State<ProjectMilestonesPage> {
  bool loading = true;
  List<Map<String, Object?>> milestones = [];
  Set<Object?> investors = {};

  bool get canManage =>
      Permissions.isAdmin || widget.project.ownerKey == widget.accountKey;
  bool get isInvestor => investors.contains(widget.accountKey);

  int percentOf(Map<String, Object?> row) =>
      (row['percent'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await CrowdRules.milestonesFor(widget.project.id!);
    final active = await CrowdRules.activeInvestments(
      projectId: widget.project.id,
    );
    if (!mounted) return;
    setState(() {
      milestones = rows;
      investors = {for (final row in active) row['ownerKey']};
      loading = false;
    });
  }

  Future<void> run(Future<Object?> Function() action, String success) async {
    try {
      await action();
      await load();
      if (!mounted) return;
      context.showMessage(success);
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  Future<void> addMilestone() async {
    final used = milestones.fold<int>(0, (sum, row) => sum + percentOf(row));
    final values = await showInputDialog(
      context,
      title: 'Nouveau jalon',
      fields: [
        const DialogField('Étape (ex. Prototype terminé)'),
        DialogField(
          'Part des fonds débloqués (%) — reste ${100 - used} %',
          number: true,
        ),
      ],
    );
    if (values == null) return;
    await run(
      () => CrowdRules.addMilestone(
        widget.project.id!,
        title: values[0],
        percent: int.tryParse(values[1].trim()) ?? 0,
      ),
      'Jalon ajouté.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final released = milestones
        .where((row) => row['status'] == 'Débloqué')
        .fold<int>(0, (sum, row) => sum + percentOf(row));
    return Scaffold(
      appBar: AppBar(title: const Text('Jalons et votes')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: addMilestone,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Ajouter un jalon'),
            )
          : null,
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ScreenHeader(
                  title: 'Fonds débloqués par étapes',
                  subtitle:
                      'Le porteur reçoit l’argent étape par étape : les '
                      'investisseurs votent pour valider chaque jalon.',
                  icon: Icons.flag_rounded,
                  stats: [
                    ('$released %', 'débloqués'),
                    (
                      formatMoney(widget.project.amountRaised * released / 100),
                      'versés au porteur',
                    ),
                    ('${investors.length}', 'votants'),
                  ],
                ),
                if (milestones.isEmpty)
                  const EmptyState(
                    icon: Icons.flag_outlined,
                    message: 'Aucun jalon défini pour ce projet.',
                  ),
                for (final milestone in milestones) _milestoneCard(milestone),
              ],
            ),
    );
  }

  Widget _milestoneCard(Map<String, Object?> milestone) {
    final status = milestone['status']?.toString() ?? 'Prévu';
    final votes = Map<String, Object?>.from(
      (milestone['votes'] as Map?) ?? const {},
    );
    final yes = votes.values.where((value) => value == true).length;
    final id = milestone['id']! as int;
    final tone = switch (status) {
      'Débloqué' => BadgeTone.success,
      'Vote en cours' => BadgeTone.info,
      'Refusé' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${milestone['title']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                StatusBadge(status, tone: tone),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${percentOf(milestone)} % des fonds • '
              '${formatMoney(widget.project.amountRaised * percentOf(milestone) / 100)}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (status == 'Vote en cours' || votes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '🗳️ $yes oui • ${votes.length - yes} non • '
                '${investors.length - votes.length} n’ont pas voté',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (canManage && (status == 'Prévu' || status == 'Refusé'))
                  FilledButton.tonalIcon(
                    onPressed: () => run(
                      () => CrowdRules.requestRelease(id),
                      'Vote ouvert : les investisseurs sont invités à voter.',
                    ),
                    icon: const Icon(Icons.how_to_vote_outlined),
                    label: const Text('Demander le déblocage'),
                  ),
                if (status == 'Vote en cours' &&
                    isInvestor &&
                    !votes.containsKey(widget.accountKey)) ...[
                  FilledButton.icon(
                    onPressed: () => run(
                      () =>
                          CrowdRules.vote(id, widget.accountKey, approve: true),
                      'Vote enregistré : oui 👍',
                    ),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: const Text('Voter oui'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => run(
                      () => CrowdRules.vote(
                        id,
                        widget.accountKey,
                        approve: false,
                      ),
                      'Vote enregistré : non 👎',
                    ),
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: const Text('Voter non'),
                  ),
                ],
                if (votes.containsKey(widget.accountKey))
                  StatusBadge(
                    votes[widget.accountKey] == true
                        ? 'Vous avez voté oui'
                        : 'Vous avez voté non',
                    tone: BadgeTone.neutral,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
