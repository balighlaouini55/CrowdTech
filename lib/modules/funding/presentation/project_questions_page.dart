// Questions-réponses d'un projet : les investisseurs demandent, le porteur
// répond.

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

class ProjectQuestionsPage extends StatefulWidget {
  final FundingProject project;
  final String accountKey;
  const ProjectQuestionsPage({
    required this.project,
    required this.accountKey,
    super.key,
  });

  @override
  State<ProjectQuestionsPage> createState() => _ProjectQuestionsPageState();
}

class _ProjectQuestionsPageState extends State<ProjectQuestionsPage> {
  bool loading = true;
  List<Map<String, Object?>> questions = [];

  bool get isOwner => widget.project.ownerKey == widget.accountKey;
  bool get canAnswer => Permissions.isAdmin || isOwner;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await CrowdRules.questionsFor(widget.project.id!);
    if (!mounted) return;
    setState(() {
      questions = rows;
      loading = false;
    });
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  Future<void> ask() async {
    final values = await showInputDialog(
      context,
      title: 'Poser une question',
      confirmLabel: 'Envoyer',
      fields: const [DialogField('Votre question au porteur', multiline: true)],
    );
    if (values == null) return;
    await run(() => CrowdRules.askQuestion(widget.project.id!, values.first));
  }

  Future<void> answer(Map<String, Object?> question) async {
    final values = await showInputDialog(
      context,
      title: 'Répondre',
      confirmLabel: 'Répondre',
      fields: [
        DialogField(
          'Votre réponse',
          initialValue: question['answer']?.toString() ?? '',
          multiline: true,
        ),
      ],
    );
    if (values == null) return;
    await run(
      () => CrowdRules.answerQuestion(question['id']! as int, values.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Questions-réponses')),
      floatingActionButton: isOwner
          ? null
          : FloatingActionButton.extended(
              onPressed: ask,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Poser une question'),
            ),
      body: loading
          ? const LoadingSkeleton()
          : questions.isEmpty
          ? const EmptyState(
              icon: Icons.question_answer_outlined,
              message: 'Aucune question pour le moment.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final question in questions) _questionCard(question),
              ],
            ),
    );
  }

  Widget _questionCard(Map<String, Object?> question) {
    final reply = question['answer']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '❓ ${question['question']}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
            Text(
              '${question['authorName'] ?? ''} • '
              '${formatDate(question['createdAt']?.toString())}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: reply == null
                    ? AppColors.warningSoft
                    : ModulePalette.funding.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                reply == null
                    ? '⏳ En attente de la réponse du porteur.'
                    : '💬 $reply',
                style: const TextStyle(height: 1.4),
              ),
            ),
            if (canAnswer)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => answer(question),
                  icon: const Icon(Icons.reply_rounded),
                  label: Text(reply == null ? 'Répondre' : 'Modifier'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
