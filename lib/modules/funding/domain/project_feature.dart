// Modèle : une fonctionnalité d'un projet (FeatureProjet), débloquée quand
// le nombre de jetons vendus atteint son seuil (collection `project_features`).

class ProjectFeature {
  final int? id;
  final int projectId;
  final String title;
  final String description;

  /// Nombre de jetons vendus nécessaire pour débloquer la fonctionnalité.
  final int tokenThreshold;

  /// Ordre de déblocage (1, 2, 3…).
  final int rank;
  final String? unlockedAt;

  const ProjectFeature({
    this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    required this.tokenThreshold,
    required this.rank,
    this.unlockedAt,
  });

  factory ProjectFeature.fromMap(Map<String, Object?> map) => ProjectFeature(
    id: map['id'] as int?,
    projectId: (map['projectId'] as num).toInt(),
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    tokenThreshold: (map['tokenThreshold'] as num?)?.toInt() ?? 0,
    rank: (map['rank'] as num?)?.toInt() ?? 0,
    unlockedAt: map['unlockedAt']?.toString(),
  );

  Map<String, Object?> toMap() => {
    'projectId': projectId,
    'title': title,
    'description': description,
    'tokenThreshold': tokenThreshold,
    'rank': rank,
    'unlockedAt': ?unlockedAt,
  };
}

/// État d'une fonctionnalité calculé à partir des jetons vendus.
enum FeatureState { unlocked, next, locked }

class FeatureProgress {
  final ProjectFeature feature;
  final FeatureState state;

  /// Avancement vers le seuil (0 à 1).
  final double progress;

  /// Jetons qui manquent pour débloquer (0 si débloquée).
  final int missingTokens;

  const FeatureProgress(
    this.feature,
    this.state,
    this.progress,
    this.missingTokens,
  );
}
