// Règles métier du crowdfunding, regroupées ici pour être testées :
//  1. tout ou rien : remboursement des projets échoués ;
//  2. validation des projets par l'administrateur ;
//  3. actualités des projets ;      4. contreparties (paliers) ;
//  5. projets suivis (favoris) ;    6. questions-réponses ;
//  7. profil investisseur et plafond ; 10. jalons et votes ;
// 11. marché des jetons (revente) ; 12. parrainage ;
// 13. achat d'un pack (écran Crowd et assistant Crowdy).
// (8. attestation PDF et 9. tableau de bord : voir leurs pages.)

import 'dart:convert';

import 'package:crowdtech/core/auth/account_repository.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/collection_repository.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/feature_unlock.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crypto/crypto.dart';

typedef CrowdRow = Map<String, Object?>;

/// Palier de contrepartie, selon le montant investi dans un projet.
class RewardTier {
  final String name;
  final String emoji;
  final double minAmount;
  final String perk;
  const RewardTier(this.name, this.emoji, this.minAmount, this.perk);
}

/// Profil investisseur issu du questionnaire, avec son plafond par projet.
class InvestorProfile {
  final String name;
  final String emoji;
  final double limitPerProject;
  final String description;
  const InvestorProfile(
    this.name,
    this.emoji,
    this.limitPerProject,
    this.description,
  );
}

class CrowdRules {
  CrowdRules._();

  static const refundedStatus = 'Remboursé';

  static String get _me => CrowdTechSession.accountKey ?? '';

  static String get _myName => CrowdTechSession.name ?? _me.split('@').first;

  static String _now() => DateTime.now().toIso8601String();

  static Future<CrowdRow?> _find(String collection, int id) =>
      CollectionRepository(collection).byId(id);

  static Future<FundingProject> _project(int projectId) async {
    final row = await _find('funding', projectId);
    if (row == null) throw const RuleException('Projet introuvable.');
    return FundingProject.fromMap(row);
  }

  static Future<void> _update(
    String collection,
    CrowdRow row,
    CrowdRow changes,
  ) =>
      CollectionRepository(collection)
          .update(row['id']! as int, {...row, ...changes}..remove('id'));

  static bool _canManage(FundingProject project) =>
      Permissions.isAdmin ||
      (project.ownerKey != null && project.ownerKey == _me);

  // ===========================================================================
  // Investissements

  /// Un investissement compte s'il n'a pas été remboursé.
  static bool isActive(CrowdRow investment) =>
      investment['status'] != refundedStatus;

  static Future<List<CrowdRow>> activeInvestments({
    int? projectId,
    String? ownerKey,
  }) async => [
    for (final row in await FundingRepository.investments.all())
      if (isActive(row) &&
          (projectId == null || row['projectId'] == projectId) &&
          (ownerKey == null || row['ownerKey'] == ownerKey))
        row,
  ];

  static double sumAmount(Iterable<CrowdRow> rows) => rows.fold(
    0,
    (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
  );

  static int sumTokens(Iterable<CrowdRow> rows) =>
      rows.fold(0, (sum, row) => sum + ((row['tokens'] as num?)?.toInt() ?? 0));

  // ===========================================================================
  // 1. Tout ou rien

  /// Rembourse les projets dont la date limite est passée sans atteindre
  /// l'objectif. Retourne le nombre de projets remboursés.
  static Future<int> processExpiredProjects() async {
    var count = 0;
    for (final row in await FundingRepository.projects.all()) {
      final project = FundingProject.fromMap(row);
      if (!project.hasFailed || project.refunded || !project.isApproved) {
        continue;
      }
      final refunds = await activeInvestments(projectId: project.id);
      for (final investment in refunds) {
        await _update('investments', investment, {
          'status': refundedStatus,
          'refundedAt': _now(),
        });
      }
      await _update('funding', row, {'refunded': true});
      await FundingRepository.logActivity(
        module: 'Crowdfunding',
        action: 'Remboursement automatique',
        details:
            '${project.title} • ${refunds.length} investissement(s) • '
            '${formatMoney(sumAmount(refunds))}',
      );
      count++;
    }
    return count;
  }

  // ===========================================================================
  // 2. Validation par l'administrateur

  /// Statut d'un nouveau projet : validé d'office s'il est publié par
  /// l'administrateur, sinon en attente.
  static String get approvalForNewProject =>
      Permissions.isAdmin ? ProjectApproval.approved : ProjectApproval.pending;

  /// Un projet non validé n'est visible que par son porteur et l'admin.
  static bool isVisible(FundingProject project, String accountKey) =>
      project.isApproved ||
      Permissions.isAdmin ||
      (project.ownerKey != null && project.ownerKey == accountKey);

  static Future<void> reviewProject(
    int projectId, {
    required bool approve,
    String reason = '',
  }) async {
    if (!Permissions.isAdmin) {
      throw const RuleException(Permissions.adminOnlyMessage);
    }
    if (!approve && reason.trim().length < 5) {
      throw const RuleException('Indiquez le motif du refus (5 caractères).');
    }
    final row = await _find('funding', projectId);
    if (row == null) throw const RuleException('Projet introuvable.');
    await _update('funding', row, {
      'approval': approve ? ProjectApproval.approved : ProjectApproval.rejected,
      'rejectionReason': approve ? null : reason.trim(),
    });
    await FundingRepository.logActivity(
      module: 'Crowdfunding',
      action: approve ? 'Projet validé' : 'Projet refusé',
      details: '${row['title']}${approve ? '' : ' • ${reason.trim()}'}',
    );
  }

  // ===========================================================================
  // 3. Actualités des projets

  static Future<List<CrowdRow>> updatesFor(Iterable<int> projectIds) async {
    final ids = projectIds.toSet();
    return [
      for (final row in (await FundingRepository.updates.all()).reversed)
        if (ids.contains(row['projectId'])) row,
    ];
  }

  static Future<void> publishUpdate(
    int projectId, {
    required String title,
    required String text,
  }) async {
    final project = await _project(projectId);
    if (!_canManage(project)) {
      throw const RuleException(
        'Seul le porteur du projet peut publier ses actualités.',
      );
    }
    if (title.trim().length < 3 || text.trim().length < 10) {
      throw const RuleException(
        'Titre (3 caractères) et message (10 caractères) requis.',
      );
    }
    await FundingRepository.updates.add({
      'projectId': projectId,
      'projectTitle': project.title,
      'title': title.trim(),
      'text': text.trim(),
      'ownerKey': _me,
      'createdAt': _now(),
    });
  }

  // ===========================================================================
  // 4. Contreparties

  static const rewardTiers = [
    RewardTier(
      'Supporter',
      '🥉',
      100,
      'Votre nom dans la page des remerciements',
    ),
    RewardTier('Ambassadeur', '🥈', 500, 'Accès anticipé à la version bêta'),
    RewardTier('Mécène', '🥇', 2000, 'Rencontre en visio avec l’équipe'),
  ];

  /// Meilleur palier atteint pour un montant, ou null.
  static RewardTier? tierFor(double amount) => rewardTiers.reversed
      .where((tier) => amount >= tier.minAmount)
      .firstOrNull;

  /// Prochain palier à atteindre, ou null si le plus haut est atteint.
  static RewardTier? nextTier(double amount) =>
      rewardTiers.where((tier) => amount < tier.minAmount).firstOrNull;

  // ===========================================================================
  // 5. Projets suivis

  static Future<Set<int>> favoriteIds(String accountKey) async => {
    for (final row in await FundingRepository.favorites.all())
      if (row['ownerKey'] == accountKey && row['projectId'] is int)
        row['projectId']! as int,
  };

  /// Suit ou ne suit plus un projet. Retourne true s'il est maintenant suivi.
  static Future<bool> toggleFavorite(int projectId, String accountKey) async {
    final existing = (await FundingRepository.favorites.all()).where(
      (row) => row['projectId'] == projectId && row['ownerKey'] == accountKey,
    );
    if (existing.isNotEmpty) {
      for (final row in existing) {
        await FundingRepository.favorites.remove(row['id']! as int);
      }
      return false;
    }
    final project = await _project(projectId);
    await FundingRepository.favorites.add({
      'projectId': projectId,
      'title': project.title,
      'ownerKey': accountKey,
      'createdAt': _now(),
    });
    return true;
  }

  // ===========================================================================
  // 6. Questions-réponses

  static Future<List<CrowdRow>> questionsFor(int projectId) async => [
    for (final row in (await FundingRepository.questions.all()).reversed)
      if (row['projectId'] == projectId) row,
  ];

  static Future<void> askQuestion(int projectId, String question) async {
    final project = await _project(projectId);
    if (project.ownerKey != null && project.ownerKey == _me) {
      throw const RuleException(
        'Vous êtes le porteur : répondez plutôt aux questions.',
      );
    }
    if (question.trim().length < 10) {
      throw const RuleException('Votre question doit faire 10 caractères.');
    }
    await FundingRepository.questions.add({
      'projectId': projectId,
      'projectTitle': project.title,
      'question': question.trim(),
      'ownerKey': _me,
      'authorName': _myName,
      'createdAt': _now(),
    });
  }

  static Future<void> answerQuestion(int questionId, String answer) async {
    final row = await _find('project_questions', questionId);
    if (row == null) throw const RuleException('Question introuvable.');
    final project = await _project(row['projectId']! as int);
    if (!_canManage(project)) {
      throw const RuleException('Seul le porteur du projet peut répondre.');
    }
    if (answer.trim().length < 5) {
      throw const RuleException('Votre réponse doit faire 5 caractères.');
    }
    await _update('project_questions', row, {
      'answer': answer.trim(),
      'answeredAt': _now(),
    });
  }

  // ===========================================================================
  // 7. Profil investisseur et plafond

  static const profiles = {
    'Prudent': InvestorProfile(
      'Prudent',
      '🐢',
      1000,
      'Vous privilégiez la sécurité : petits montants, beaucoup de projets.',
    ),
    'Équilibré': InvestorProfile(
      'Équilibré',
      '🦊',
      5000,
      'Vous acceptez un risque mesuré pour soutenir des projets prometteurs.',
    ),
    'Dynamique': InvestorProfile(
      'Dynamique',
      '🚀',
      20000,
      'Vous acceptez un risque élevé et connaissez bien le crowdfunding.',
    ),
  };

  /// Plafond sans questionnaire rempli.
  static const standardLimit = 5000.0;

  /// Questionnaire : 3 questions notées de 0 à 2 → profil.
  static String profileForScore(int score) => score <= 2
      ? 'Prudent'
      : score <= 4
      ? 'Équilibré'
      : 'Dynamique';

  static Future<InvestorProfile?> profileOf(String accountKey) async {
    final row = (await FundingRepository.investorProfiles.ownedBy(accountKey))
        .lastOrNull;
    return profiles[row?['profile']];
  }

  static Future<InvestorProfile> saveProfile(
    String accountKey,
    List<int> answers,
  ) async {
    final name = profileForScore(answers.fold(0, (a, b) => a + b));
    final payload = {
      'ownerKey': accountKey,
      'profile': name,
      'answers': answers,
      'createdAt': _now(),
    };
    final existing = (await FundingRepository.investorProfiles.ownedBy(
      accountKey,
    )).firstOrNull;
    existing == null
        ? await FundingRepository.investorProfiles.add(payload)
        : await _update('investor_profiles', existing, payload);
    return profiles[name]!;
  }

  static Future<double> limitFor(String accountKey) async =>
      (await profileOf(accountKey))?.limitPerProject ?? standardLimit;

  /// Montant que l'utilisateur peut encore investir dans ce projet.
  static Future<double> remainingAllowance(
    int projectId,
    String accountKey,
  ) async {
    final invested = sumAmount(
      await activeInvestments(projectId: projectId, ownerKey: accountKey),
    );
    return (await limitFor(accountKey) - invested).clamp(0, double.infinity);
  }

  // ===========================================================================
  // 10. Jalons et votes

  static Future<List<CrowdRow>> milestonesFor(int projectId) async => [
    for (final row in await FundingRepository.milestones.all())
      if (row['projectId'] == projectId) row,
  ];

  static Future<void> addMilestone(
    int projectId, {
    required String title,
    required int percent,
  }) async {
    final project = await _project(projectId);
    if (!_canManage(project)) {
      throw const RuleException(
        'Seul le porteur du projet peut définir les jalons.',
      );
    }
    if (title.trim().length < 3) {
      throw const RuleException('Donnez un titre au jalon (3 caractères).');
    }
    final used = (await milestonesFor(projectId)).fold<int>(
      0,
      (sum, row) => sum + ((row['percent'] as num?)?.toInt() ?? 0),
    );
    if (percent < 1 || used + percent > 100) {
      throw RuleException(
        'Pourcentage invalide : il reste ${100 - used} % des fonds à répartir.',
      );
    }
    await FundingRepository.milestones.add({
      'projectId': projectId,
      'title': title.trim(),
      'percent': percent,
      'status': 'Prévu',
      'votes': <String, bool>{},
      'ownerKey': _me,
      'createdAt': _now(),
    });
  }

  /// Le porteur demande le déblocage des fonds d'un jalon : les
  /// investisseurs votent. Seulement si la collecte a réussi.
  static Future<void> requestRelease(int milestoneId) async {
    final row = await _find('milestones', milestoneId);
    if (row == null) throw const RuleException('Jalon introuvable.');
    final project = await _project(row['projectId']! as int);
    if (!_canManage(project)) {
      throw const RuleException('Seul le porteur peut demander le déblocage.');
    }
    if (!project.isFunded) {
      throw const RuleException(
        'Les fonds ne peuvent être débloqués qu’une fois l’objectif atteint.',
      );
    }
    if (row['status'] == 'Débloqué' || row['status'] == 'Vote en cours') {
      throw const RuleException('Ce jalon est déjà en vote ou débloqué.');
    }
    await _update('milestones', row, {
      'status': 'Vote en cours',
      'votes': <String, bool>{},
    });
  }

  /// Vote d'un investisseur du projet (un vote par personne). Le jalon est
  /// débloqué dès que plus de la moitié des investisseurs a voté oui, et
  /// refusé dès que la moitié ou plus a voté non.
  static Future<String> vote(
    int milestoneId,
    String accountKey, {
    required bool approve,
  }) async {
    final row = await _find('milestones', milestoneId);
    if (row == null) throw const RuleException('Jalon introuvable.');
    if (row['status'] != 'Vote en cours') {
      throw const RuleException('Aucun vote n’est ouvert pour ce jalon.');
    }
    final projectId = row['projectId']! as int;
    final voters = {
      for (final investment in await activeInvestments(projectId: projectId))
        investment['ownerKey'],
    };
    if (!voters.contains(accountKey)) {
      throw const RuleException(
        'Seuls les investisseurs de ce projet peuvent voter.',
      );
    }
    final votes = Map<String, Object?>.from((row['votes'] as Map?) ?? const {});
    if (votes.containsKey(accountKey)) {
      throw const RuleException('Vous avez déjà voté pour ce jalon.');
    }
    votes[accountKey] = approve;
    final yes = votes.values.where((value) => value == true).length;
    final no = votes.length - yes;
    final status = yes * 2 > voters.length
        ? 'Débloqué'
        : no * 2 >= voters.length
        ? 'Refusé'
        : 'Vote en cours';
    await _update('milestones', row, {'votes': votes, 'status': status});
    return status;
  }

  // ===========================================================================
  // 11. Marché des jetons

  /// Jetons que l'utilisateur détient dans un projet, moins ceux déjà mis
  /// en vente.
  static Future<int> availableTokens(int projectId, String accountKey) async {
    final held = sumTokens(
      await activeInvestments(projectId: projectId, ownerKey: accountKey),
    );
    final listed = [
      for (final row in await FundingRepository.tokenListings.all())
        if (row['projectId'] == projectId &&
            row['sellerKey'] == accountKey &&
            row['status'] == 'En vente')
          (row['tokens'] as num).toInt(),
    ].fold(0, (a, b) => a + b);
    return held - listed;
  }

  static Future<List<CrowdRow>> openListings() async => [
    for (final row in (await FundingRepository.tokenListings.all()).reversed)
      if (row['status'] == 'En vente') row,
  ];

  static Future<void> createListing(
    int projectId, {
    required int tokens,
    required double pricePerToken,
  }) async {
    final project = await _project(projectId);
    if (project.hasFailed || project.refunded) {
      throw const RuleException(
        'Ce projet a échoué : ses jetons ne peuvent pas être revendus.',
      );
    }
    if (tokens < 1) throw const RuleException('Indiquez au moins 1 jeton.');
    if (pricePerToken <= 0) {
      throw const RuleException('Indiquez un prix supérieur à 0 €.');
    }
    final available = await availableTokens(projectId, _me);
    if (tokens > available) {
      throw RuleException(
        'Vous ne pouvez vendre que $available jeton(s) de ce projet.',
      );
    }
    await FundingRepository.tokenListings.add({
      'projectId': projectId,
      'projectTitle': project.title,
      'tokens': tokens,
      'pricePerToken': pricePerToken,
      'sellerKey': _me,
      'ownerKey': _me,
      'status': 'En vente',
      'createdAt': _now(),
    });
  }

  static Future<void> cancelListing(int listingId) async {
    final row = await _find('token_listings', listingId);
    if (row == null || row['status'] != 'En vente') {
      throw const RuleException('Cette annonce n’est plus en vente.');
    }
    if (row['sellerKey'] != _me && !Permissions.isAdmin) {
      throw const RuleException('Ce n’est pas votre annonce.');
    }
    await _update('token_listings', row, {'status': 'Annulée'});
  }

  /// Achat d'une annonce : les jetons passent du vendeur à l'acheteur.
  /// La collecte du projet ne change pas (c'est une revente).
  static Future<void> buyListing(int listingId, String buyerKey) async {
    final row = await _find('token_listings', listingId);
    if (row == null || row['status'] != 'En vente') {
      throw const RuleException('Cette annonce n’est plus en vente.');
    }
    final seller = row['sellerKey']! as String;
    if (seller == buyerKey) {
      throw const RuleException('Vous ne pouvez pas acheter votre annonce.');
    }
    final projectId = row['projectId']! as int;
    final tokens = (row['tokens']! as num).toInt();
    final total = tokens * (row['pricePerToken']! as num).toDouble();
    // Le vendeur doit toujours posséder ces jetons.
    final held = sumTokens(
      await activeInvestments(projectId: projectId, ownerKey: seller),
    );
    if (held < tokens) {
      await _update('token_listings', row, {'status': 'Annulée'});
      throw const RuleException('Le vendeur ne possède plus ces jetons.');
    }
    final common = {
      'projectId': projectId,
      'projectTitle': row['projectTitle'],
      'pack': 'Revente',
      'bonusTokens': 0,
      'listingId': listingId,
      'createdAt': _now(),
    };
    await FundingRepository.investments.add({
      ...common,
      'type': 'Vente',
      'tokens': -tokens,
      'amount': -total,
      'ownerKey': seller,
    });
    await FundingRepository.investments.add({
      ...common,
      'type': 'Achat',
      'tokens': tokens,
      'amount': total,
      'ownerKey': buyerKey,
    });
    await _update('token_listings', row, {
      'status': 'Vendue',
      'buyerKey': buyerKey,
      'soldAt': _now(),
    });
  }

  // ===========================================================================
  // 12. Parrainage

  /// Code de parrainage d'un compte, par exemple « CT-3F9A2C ».
  static String referralCodeFor(String email) =>
      'CT-${sha256.convert(utf8.encode(email.trim().toLowerCase())).toString().substring(0, 6).toUpperCase()}';

  /// Email du parrain correspondant au code, ou null s'il n'existe pas.
  static Future<String?> referrerFor(String code) async {
    final wanted = code.trim().toUpperCase();
    for (final account in await AccountRepository.accounts.all()) {
      final email = account['email']?.toString() ?? '';
      if (email.isNotEmpty && referralCodeFor(email) == wanted) return email;
    }
    return null;
  }

  /// Bonus de parrainage : 10 % de jetons offerts sur le prochain pack du
  /// parrain et du filleul.
  static const referralBonusPercent = 10;

  static Future<void> recordReferral({
    required String referrerKey,
    required String refereeKey,
  }) async {
    if (referrerKey == refereeKey) {
      throw const RuleException('Vous ne pouvez pas vous parrainer vous-même.');
    }
    await FundingRepository.referrals.add({
      'referrerKey': referrerKey,
      'refereeKey': refereeKey,
      'ownerKey': refereeKey,
      'referrerBonusUsed': false,
      'refereeBonusUsed': false,
      'createdAt': _now(),
    });
  }

  static Future<List<CrowdRow>> referralsOf(String accountKey) async => [
    for (final row in await FundingRepository.referrals.all())
      if (row['referrerKey'] == accountKey) row,
  ];

  /// Bonus encore disponibles (1 par filleul, + 1 si on a été parrainé).
  static Future<int> availableBonuses(String accountKey) async =>
      (await FundingRepository.referrals.all()).fold<int>(0, (count, row) {
        if (row['referrerKey'] == accountKey &&
            row['referrerBonusUsed'] != true) {
          count++;
        }
        if (row['refereeKey'] == accountKey &&
            row['refereeBonusUsed'] != true) {
          count++;
        }
        return count;
      });

  /// Utilise un bonus disponible. Retourne les jetons offerts (0 si aucun).
  static Future<int> consumeReferralBonus(
    String accountKey,
    int packTokens,
  ) async {
    for (final row in await FundingRepository.referrals.all()) {
      final key =
          row['referrerKey'] == accountKey && row['referrerBonusUsed'] != true
          ? 'referrerBonusUsed'
          : row['refereeKey'] == accountKey && row['refereeBonusUsed'] != true
          ? 'refereeBonusUsed'
          : null;
      if (key == null) continue;
      await _update('referrals', row, {key: true});
      return (packTokens * referralBonusPercent / 100).ceil();
    }
    return 0;
  }

  // ===========================================================================
  // 13. Achat d'un pack

  /// Raison pour laquelle [accountKey] ne peut pas acheter [pack] dans
  /// [project], ou `null` si l'achat est possible.
  static Future<String?> purchaseBlocker(
    FundingProject project,
    TokenPack pack,
    String accountKey,
  ) async {
    if (!project.isApproved) {
      return project.approval == ProjectApproval.rejected
          ? 'Ce projet a été refusé par l’administrateur.'
          : 'Ce projet attend la validation de l’administrateur.';
    }
    if (project.isClosed) return 'La collecte de ce projet est clôturée.';
    if (project.ownerKey != null && project.ownerKey == accountKey) {
      return 'C’est votre projet : vous ne pouvez pas y investir vous-même.';
    }
    if (project.isFunded) {
      return 'Objectif atteint : ce projet est déjà financé.';
    }
    final price = pack.priceFor(project.tokenPrice);
    final remaining = project.goal - project.amountRaised;
    if (price > remaining) {
      return 'Le pack ${pack.name} (${formatMoney(price)}) dépasse le montant '
          'qui reste à collecter (${formatMoney(remaining)}).';
    }
    final allowance = await remainingAllowance(project.id!, accountKey);
    if (price > allowance) {
      return 'Le pack ${pack.name} (${formatMoney(price)}) dépasse votre '
          'plafond restant pour ce projet (${formatMoney(allowance)}). '
          'Vous pouvez le modifier avec votre profil investisseur.';
    }
    return null;
  }

  /// Achète [pack] dans le projet [projectId] (données relues dans la base).
  /// Lève une [RuleException] si une règle l'interdit.
  static Future<PackPurchase> buyPack({
    required int projectId,
    required TokenPack pack,
    required String accountKey,
  }) async {
    final project = await _project(projectId);
    final blocker = await purchaseBlocker(
      project.copyWithId(projectId),
      pack,
      accountKey,
    );
    if (blocker != null) throw RuleException(blocker);
    final price = pack.priceFor(project.tokenPrice);
    // Parrainage : +10 % de jetons offerts si un bonus est disponible.
    final referralTokens = await consumeReferralBonus(accountKey, pack.tokens);
    final updated = project
        .copyWithId(projectId)
        .copyWithRaised(
          (project.amountRaised + price).clamp(0, project.goal).toDouble(),
        );
    final tokens = pack.totalTokens + referralTokens;
    final investmentId = await FundingRepository.saveInvestment(
      projectId: projectId,
      updatedProject: updated.toMap(),
      investment: {
        'projectId': projectId,
        'projectTitle': project.title,
        'pack': pack.name,
        'type': 'Pack',
        'tokens': tokens,
        'bonusTokens': pack.bonusTokens + referralTokens,
        if (referralTokens > 0) 'referralBonus': referralTokens,
        'amount': price,
        'ownerKey': accountKey,
        'createdAt': _now(),
      },
    );
    if (investmentId == 0) {
      throw const RuleException('Le projet à mettre à jour est introuvable.');
    }
    // Fonctionnalités débloquées grâce aux nouveaux jetons vendus.
    final unlocked = await FeatureUnlock.refreshUnlocks(projectId);
    return PackPurchase(
      project: updated,
      pack: pack,
      amount: price,
      tokens: tokens,
      referralTokens: referralTokens,
      unlockedFeatures: unlocked,
    );
  }
}

/// Résultat d'un achat de pack.
class PackPurchase {
  final FundingProject project;
  final TokenPack pack;
  final double amount;
  final int tokens;
  final int referralTokens;

  /// Fonctionnalités du projet débloquées par cet achat.
  final List<String> unlockedFeatures;
  const PackPurchase({
    required this.project,
    required this.pack,
    required this.amount,
    required this.tokens,
    required this.referralTokens,
    this.unlockedFeatures = const [],
  });

  String get summary =>
      'Pack ${pack.name} acheté : $tokens jeton(s) crédité(s) pour '
      '${project.title} (${formatMoney(amount)}, mode démo)'
      '${referralTokens > 0 ? ', dont +$referralTokens bonus de parrainage 🎁' : ''}.'
      '${unlockedFeatures.isEmpty ? '' : ' 🔓 Débloqué : ${unlockedFeatures.join(', ')}.'}';
}
