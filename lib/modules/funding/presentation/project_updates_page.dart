// Actualités d'un projet : le porteur publie, tout le monde lit.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

class ProjectUpdatesPage extends StatefulWidget {
  final FundingProject project;
  final String accountKey;
  const ProjectUpdatesPage({
    required this.project,
    required this.accountKey,
    super.key,
  });

  @override
  State<ProjectUpdatesPage> createState() => _ProjectUpdatesPageState();
}

class _ProjectUpdatesPageState extends State<ProjectUpdatesPage> {
  bool loading = true;
  List<Map<String, Object?>> updates = [];

  bool get canPublish =>
      Permissions.isAdmin || widget.project.ownerKey == widget.accountKey;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await CrowdRules.updatesFor([widget.project.id!]);
    if (!mounted) return;
    setState(() {
      updates = rows;
      loading = false;
    });
  }

  Future<void> publish() async {
    final values = await showInputDialog(
      context,
      title: 'Nouvelle actualité',
      confirmLabel: 'Publier',
      fields: const [
        DialogField('Titre'),
        DialogField('Message aux investisseurs', multiline: true),
      ],
    );
    if (values == null || !mounted) return;
    try {
      await CrowdRules.publishUpdate(
        widget.project.id!,
        title: values[0],
        text: values[1],
      );
      await load();
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actualités du projet')),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: publish,
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Publier'),
            )
          : null,
      body: loading
          ? const LoadingSkeleton()
          : updates.isEmpty
          ? const EmptyState(
              icon: Icons.campaign_outlined,
              message: 'Le porteur n’a encore publié aucune actualité.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final update in updates)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('📣', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${update['title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${update['text']}',
                            style: const TextStyle(height: 1.45),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatDateTime(update['createdAt']?.toString()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
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
