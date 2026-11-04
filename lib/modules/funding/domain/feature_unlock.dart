// Déblocage séquentiel des fonctionnalités d'un projet par seuils de
// jetons : la fonctionnalité n°2 ne peut être débloquée qu'après la n°1,
// et chacune exige un nombre de jetons vendus plus grand que la précédente.

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/project_feature.dart';

class FeatureUnlock {
  FeatureUnlock._();

  /// Fonctionnalités d'un projet, dans l'ordre de déblocage.
  static Future<List<ProjectFeature>> featuresOf(int projectId) async {
    final rows = await FundingRepository.features.all();
    return [
      for (final row in rows)
        if ((row['projectId'] as num?)?.toInt() == projectId)
          ProjectFeature.fromMap(row),
    ]..sort((a, b) => a.rank.compareTo(b.rank));
  }

  /// Jetons vendus d'un projet (investissements non remboursés).
  static Future<int> tokensSold(int projectId) async => CrowdRules.sumTokens(
    await CrowdRules.activeInvestments(projectId: projectId),
  );

  /// Calcule l'état de chaque fonctionnalité. Le déblocage est
  /// séquentiel : dès qu'une fonctionnalité est verrouillée, les suivantes
  /// le sont aussi, même si leur seuil était atteint.
  static List<FeatureProgress> evaluate(
    List<ProjectFeature> features,
    int tokensSold,
  ) {
    final sorted = [...features]..sort((a, b) => a.rank.compareTo(b.rank));
    final result = <FeatureProgress>[];
    var blocked = false;
    var previousThreshold = 0;
    for (final feature in sorted) {
      final reached = tokensSold >= feature.tokenThreshold;
      if (!blocked && reached) {
        result.add(FeatureProgress(feature, FeatureState.unlocked, 1, 0));
      } else {
        // Progression mesurée depuis le seuil précédent.
        final span = (feature.tokenThreshold - previousThreshold).clamp(
          1,
          1 << 30,
        );
        final progress = blocked
            ? 0.0
            : ((tokensSold - previousThreshold) / span).clamp(0.0, 1.0);
        result.add(
          FeatureProgress(
            feature,
            blocked ? FeatureState.locked : FeatureState.next,
            progress,
            (feature.tokenThreshold - tokensSold).clamp(0, 1 << 30),
          ),
        );
        blocked = true;
      }
      previousThreshold = feature.tokenThreshold;
    }
    return result;
  }

  /// Nombre maximal de jetons du projet (objectif / prix du jeton).
  static int maxTokens(FundingProject project) =>
      project.tokenPrice <= 0 ? 0 : (project.goal / project.tokenPrice).floor();

  /// Ajoute une fonctionnalité. Son seuil doit dépasser celui de la
  /// précédente et rester atteignable (≤ nombre maximal de jetons).
  static Future<ProjectFeature> addFeature(
    FundingProject project, {
    required String title,
    String description = '',
    required int tokenThreshold,
  }) async {
    final me = CrowdTechSession.accountKey;
    if (!Permissions.isAdmin && (me == null || project.ownerKey != me)) {
      throw const RuleException(
        'Seul le porteur du projet peut définir les fonctionnalités.',
      );
    }
    if (title.trim().length < 3) {
      throw const RuleException(
        'Donnez un nom à la fonctionnalité (3 caractères).',
      );
    }
    final existing = await featuresOf(project.id!);
    final last = existing.isEmpty ? 0 : existing.last.tokenThreshold;
    if (tokenThreshold <= last) {
      throw RuleException(
        'Le seuil doit dépasser celui de la fonctionnalité précédente '
        '($last jetons).',
      );
    }
    final maximum = maxTokens(project);
    if (maximum > 0 && tokenThreshold > maximum) {
      throw RuleException(
        'Seuil inatteignable : le projet émet au plus $maximum jetons.',
      );
    }
    final feature = ProjectFeature(
      projectId: project.id!,
      title: title.trim(),
      description: description.trim(),
      tokenThreshold: tokenThreshold,
      rank: existing.length + 1,
    );
    final id = await FundingRepository.features.add(feature.toMap());
    await refreshUnlocks(project.id!);
    return ProjectFeature.fromMap({'id': id, ...feature.toMap()});
  }

  /// Enregistre la date de déblocage des fonctionnalités qui viennent
  /// d'être débloquées. Retourne leurs noms.
  static Future<List<String>> refreshUnlocks(int projectId) async {
    final features = await featuresOf(projectId);
    final states = evaluate(features, await tokensSold(projectId));
    final newlyUnlocked = <String>[];
    for (final item in states) {
      final feature = item.feature;
      if (item.state == FeatureState.unlocked &&
          feature.unlockedAt == null &&
          feature.id != null) {
        await FundingRepository.features.update(feature.id!, {
          ...feature.toMap(),
          'unlockedAt': DateTime.now().toIso8601String(),
        });
        newlyUnlocked.add(feature.title);
      }
    }
    return newlyUnlocked;
  }
}
