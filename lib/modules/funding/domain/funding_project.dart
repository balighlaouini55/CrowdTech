// Modèle : un projet de crowdfunding (objectif, montant levé, date limite…).

class FundingProject {
  final int? id;
  final String title;
  final String company;
  final double amountRaised;
  final double goal;
  final double tokenPrice;
  final int progress;
  final String feature;
  final String? category;
  final String? description;
  final String? deadline;
  final String? ownerKey;
  final String? imageUrl;
  final String? imageData;
  final String? stage;
  final String? location;
  final String? website;
  final int? teamSize;

  /// Validation par l'administrateur : [ProjectApproval].
  final String approval;
  final String? rejectionReason;

  /// Collecte échouée (date passée sans atteindre l'objectif) : les
  /// investisseurs ont été remboursés.
  final bool refunded;
  const FundingProject({
    this.id,
    required this.title,
    required this.company,
    required this.amountRaised,
    required this.goal,
    required this.tokenPrice,
    required this.progress,
    required this.feature,
    this.category,
    this.description,
    this.deadline,
    this.ownerKey,
    this.imageUrl,
    this.imageData,
    this.stage,
    this.location,
    this.website,
    this.teamSize,
    this.approval = ProjectApproval.approved,
    this.rejectionReason,
    this.refunded = false,
  });

  factory FundingProject.fromMap(Map<String, Object?> map) => FundingProject(
    id: map['id'] as int?,
    title: map['title']! as String,
    company: map['company']! as String,
    amountRaised: (map['amountRaised']! as num).toDouble(),
    goal: (map['goal']! as num).toDouble(),
    tokenPrice: (map['tokenPrice']! as num).toDouble(),
    progress: (map['progress']! as num).toInt(),
    feature: map['feature']! as String,
    category: map['category'] as String?,
    description: map['description'] as String?,
    deadline: map['deadline'] as String?,
    ownerKey: map['ownerKey'] as String?,
    imageUrl: map['imageUrl'] as String?,
    imageData: map['imageData'] as String?,
    stage: map['stage'] as String?,
    location: map['location'] as String?,
    website: map['website'] as String?,
    teamSize: (map['teamSize'] as num?)?.toInt(),
    approval: map['approval'] as String? ?? ProjectApproval.approved,
    rejectionReason: map['rejectionReason'] as String?,
    refunded: map['refunded'] == true,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'company': company,
    'amountRaised': amountRaised,
    'goal': goal,
    'tokenPrice': tokenPrice,
    'progress': progress,
    'feature': feature,
    'category': ?category,
    'description': ?description,
    'deadline': ?deadline,
    'ownerKey': ?ownerKey,
    'imageUrl': ?imageUrl,
    'imageData': ?imageData,
    'stage': ?stage,
    'location': ?location,
    'website': ?website,
    'teamSize': ?teamSize,
    'approval': approval,
    'rejectionReason': ?rejectionReason,
    if (refunded) 'refunded': true,
  };

  /// Date limite dépassée : la collecte est clôturée.
  bool get isClosed {
    final end = DateTime.tryParse(deadline ?? '');
    if (end == null) return false;
    final today = DateTime.now();
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get isFunded => amountRaised >= goal;

  bool get isApproved => approval == ProjectApproval.approved;

  /// « Tout ou rien » : date passée sans atteindre l'objectif.
  bool get hasFailed => isClosed && !isFunded;

  /// On peut investir : projet validé, en cours et pas encore financé.
  bool get acceptsInvestments => isApproved && !isClosed && !isFunded;

  /// Statut affiché sur les cartes.
  String get statusLabel => switch (this) {
    _ when approval == ProjectApproval.pending => 'En attente de validation',
    _ when approval == ProjectApproval.rejected => 'Refusé',
    _ when isFunded => 'Financé',
    _ when refunded => 'Échoué – remboursé',
    _ when hasFailed => 'Échoué',
    _ => 'En cours',
  };

  /// Nombre de jours restants, ou null si aucune date limite.
  int? get daysLeft {
    final end = DateTime.tryParse(deadline ?? '');
    if (end == null) return null;
    final today = DateTime.now();
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  FundingProject copyWithId(int value) =>
      FundingProject.fromMap({...toMap(), 'id': value});

  FundingProject copyWithRaised(double amount) => FundingProject.fromMap({
    'id': id,
    ...toMap(),
    'amountRaised': amount,
    'progress': (amount / goal * 100).round().clamp(0, 100),
  });
}

/// États de validation d'un projet par l'administrateur.
class ProjectApproval {
  ProjectApproval._();

  static const pending = 'En attente';
  static const approved = 'Validé';
  static const rejected = 'Refusé';
}
