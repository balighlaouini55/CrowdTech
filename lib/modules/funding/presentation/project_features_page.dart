// Fonctionnalités d'un projet (FeatureProjet) : chacune se débloque quand
// le nombre de jetons vendus atteint son seuil, dans l'ordre.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/domain/feature_unlock.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/project_feature.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class ProjectFeaturesPage extends StatefulWidget {
  final FundingProject project;
  final String accountKey;
  const ProjectFeaturesPage({
    required this.project,
    required this.accountKey,
    super.key,
  });

  @override
  State<ProjectFeaturesPage> createState() => _ProjectFeaturesPageState();
}

class _ProjectFeaturesPageState extends State<ProjectFeaturesPage> {
  bool loading = true;
  int sold = 0;
  List<FeatureProgress> states = [];

  bool get canManage =>
      Permissions.isAdmin || widget.project.ownerKey == widget.accountKey;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.project.id!;
    await FeatureUnlock.refreshUnlocks(id);
    final features = await FeatureUnlock.featuresOf(id);
    final tokens = await FeatureUnlock.tokensSold(id);
    if (!mounted) return;
    setState(() {
      sold = tokens;
      states = FeatureUnlock.evaluate(features, tokens);
      loading = false;
    });
  }

  Future<void> addFeature() async {
    final last = states.isEmpty ? 0 : states.last.feature.tokenThreshold;
    final maximum = FeatureUnlock.maxTokens(widget.project);
    final values = await showInputDialog(
      context,
      title: 'Nouvelle fonctionnalité',
      fields: [
        const DialogField('Nom (ex. Application mobile)'),
        const DialogField('Description (facultatif)', multiline: true),
        DialogField('Seuil en jetons (> $last, max $maximum)', number: true),
      ],
    );
    if (values == null) return;
    try {
      await FeatureUnlock.addFeature(
        widget.project,
        title: values[0],
        description: values[1],
        tokenThreshold: int.tryParse(values[2].trim()) ?? 0,
      );
      await load();
      if (!mounted) return;
      context.showMessage('Fonctionnalité ajoutée ✨');
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = states
        .where((item) => item.state == FeatureState.unlocked)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Fonctionnalités à débloquer')),
      floatingActionButton: canManage && !loading
          ? FloatingActionButton.extended(
              onPressed: addFeature,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            )
          : null,
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ScreenHeader(
                  title: 'Financement par fonctionnalités',
                  subtitle:
                      'Chaque palier de jetons vendus débloque la '
                      'fonctionnalité suivante, dans l’ordre.',
                  icon: Icons.lock_open_rounded,
                  stats: [
                    ('$sold', 'jetons vendus'),
                    ('$unlocked/${states.length}', 'débloquées'),
                    (formatMoney(widget.project.tokenPrice), 'le jeton'),
                  ],
                ),
                if (states.isEmpty)
                  EmptyState(
                    icon: Icons.extension_outlined,
                    message: canManage
                        ? 'Ajoutez les fonctionnalités de votre projet et '
                              'le nombre de jetons qui les débloque.'
                        : 'Le porteur n’a pas encore détaillé les '
                              'fonctionnalités.',
                  )
                else
                  for (final item in states) _FeatureTile(item),
              ],
            ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final FeatureProgress item;
  const _FeatureTile(this.item);

  @override
  Widget build(BuildContext context) {
    final feature = item.feature;
    final palette = ModulePalette.funding;
    final (emoji, label, color) = switch (item.state) {
      FeatureState.unlocked => ('🔓', 'Débloquée', AppColors.success),
      FeatureState.next => ('⏳', 'Prochaine', palette.start),
      FeatureState.locked => ('🔒', 'Verrouillée', AppColors.muted),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.state == FeatureState.unlocked
                        ? AppColors.successSoft
                        : palette.soft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${feature.rank}. ${feature.title}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '$label · seuil ${feature.tokenThreshold} jetons',
                        style: TextStyle(color: color, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (feature.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                feature.description,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (item.state != FeatureState.unlocked) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 8,
                  color: palette.start,
                  backgroundColor: palette.soft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.state == FeatureState.next
                    ? 'Encore ${item.missingTokens} jeton(s) à vendre'
                    : 'Se débloque après la fonctionnalité précédente',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ] else if (feature.unlockedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Débloquée le ${formatDate(feature.unlockedAt)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
