// Les 12 fonctionnalités métier du crowdfunding.

import 'dart:async';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/data/certificate_pdf.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/presentation/owner_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const owner = CrowdUser(
  name: 'Porteur',
  email: 'porteur@example.com',
  role: UserRoles.projectOwner,
);
const investorA = CrowdUser(
  name: 'Alice',
  email: 'alice@example.com',
  role: UserRoles.investor,
);
const investorB = CrowdUser(
  name: 'Bob',
  email: 'bob@example.com',
  role: UserRoles.investor,
);

String isoDaysFromNow(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;

Future<int> addProject({
  double raised = 0,
  double goal = 1000,
  String deadline = '2099-12-31',
  String approval = ProjectApproval.approved,
}) => CrowdTechDatabase.insertItem('funding', {
  'title': 'Projet test',
  'company': 'Société',
  'amountRaised': raised,
  'goal': goal,
  'tokenPrice': 10.0,
  'progress': (raised / goal * 100).round(),
  'feature': 'Fonction',
  'deadline': deadline,
  'ownerKey': owner.email,
  'approval': approval,
});

Future<void> invest(int projectId, CrowdUser user, double amount, int tokens) =>
    CrowdTechDatabase.insertItem('investments', {
      'projectId': projectId,
      'projectTitle': 'Projet test',
      'pack': 'Supporter',
      'tokens': tokens,
      'amount': amount,
      'ownerKey': user.email,
      'createdAt': DateTime.now().toIso8601String(),
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await CrowdTechDatabase.useMemoryForTesting();
    CrowdTechSession.start(owner);
  });

  test(
    '1. tout ou rien : une collecte échouée est remboursée une fois',
    () async {
      final failed = await addProject(
        raised: 300,
        deadline: isoDaysFromNow(-1),
      );
      final funded = await addProject(
        raised: 1000,
        deadline: isoDaysFromNow(-1),
      );
      await invest(failed, investorA, 300, 30);
      await invest(funded, investorA, 1000, 100);

      expect(await CrowdRules.processExpiredProjects(), 1);
      expect(await CrowdRules.processExpiredProjects(), 0);

      final rows = await CrowdTechDatabase.getItems('investments');
      expect(
        rows.firstWhere((row) => row['projectId'] == failed)['status'],
        CrowdRules.refundedStatus,
      );
      expect(
        rows.firstWhere((row) => row['projectId'] == funded)['status'],
        null,
      );
      final project = FundingProject.fromMap(
        (await CrowdTechDatabase.getItems('funding')).first,
      );
      expect(project.refunded, isTrue);
      expect(project.statusLabel, 'Échoué – remboursé');
    },
  );

  test('2. un projet doit être validé par l’administrateur', () async {
    expect(CrowdRules.approvalForNewProject, ProjectApproval.pending);
    final id = await addProject(approval: ProjectApproval.pending);
    final pending = FundingProject.fromMap(
      (await CrowdTechDatabase.getItems('funding')).single,
    );
    expect(pending.acceptsInvestments, isFalse);
    expect(CrowdRules.isVisible(pending, investorA.email), isFalse);
    expect(CrowdRules.isVisible(pending, owner.email), isTrue);

    await expectLater(
      CrowdRules.reviewProject(id, approve: true),
      throwsA(isA<RuleException>()),
    );
    CrowdTechSession.start(testAdmin);
    await expectLater(
      CrowdRules.reviewProject(id, approve: false),
      throwsA(isA<RuleException>()),
    );
    await CrowdRules.reviewProject(id, approve: true);
    final approved = FundingProject.fromMap(
      (await CrowdTechDatabase.getItems('funding')).single,
    );
    expect(approved.isApproved, isTrue);
    expect(approved.acceptsInvestments, isTrue);
  });

  test('3. seul le porteur publie les actualités de son projet', () async {
    final id = await addProject();
    await CrowdRules.publishUpdate(
      id,
      title: 'Prototype prêt',
      text: 'Le prototype est terminé et testé.',
    );
    CrowdTechSession.start(investorA);
    await expectLater(
      CrowdRules.publishUpdate(id, title: 'Pirate', text: 'Message pirate !!'),
      throwsA(isA<RuleException>()),
    );
    final updates = await CrowdRules.updatesFor([id]);
    expect(updates.single['title'], 'Prototype prêt');
  });

  test('4. contreparties : palier atteint et prochain palier', () {
    expect(CrowdRules.tierFor(50), isNull);
    expect(CrowdRules.tierFor(100)?.name, 'Supporter');
    expect(CrowdRules.tierFor(750)?.name, 'Ambassadeur');
    expect(CrowdRules.nextTier(750)?.name, 'Mécène');
    expect(CrowdRules.nextTier(5000), isNull);
  });

  test('5. suivre puis ne plus suivre un projet', () async {
    final id = await addProject();
    expect(await CrowdRules.toggleFavorite(id, investorA.email), isTrue);
    expect(await CrowdRules.favoriteIds(investorA.email), {id});
    expect(await CrowdRules.toggleFavorite(id, investorA.email), isFalse);
    expect(await CrowdRules.favoriteIds(investorA.email), isEmpty);
  });

  test('6. questions-réponses : on demande, le porteur répond', () async {
    final id = await addProject();
    await expectLater(
      CrowdRules.askQuestion(id, 'Question du porteur lui-même ?'),
      throwsA(isA<RuleException>()),
    );
    CrowdTechSession.start(investorA);
    await CrowdRules.askQuestion(id, 'Quand sortira la première version ?');
    final question = (await CrowdRules.questionsFor(id)).single;
    await expectLater(
      CrowdRules.answerQuestion(
        question['id']! as int,
        'Je ne suis pas le porteur',
      ),
      throwsA(isA<RuleException>()),
    );
    CrowdTechSession.start(owner);
    await CrowdRules.answerQuestion(question['id']! as int, 'En mars 2027.');
    expect(
      (await CrowdRules.questionsFor(id)).single['answer'],
      'En mars 2027.',
    );
  });

  test('7. le profil investisseur fixe le plafond par projet', () async {
    expect(CrowdRules.profileForScore(0), 'Prudent');
    expect(CrowdRules.profileForScore(3), 'Équilibré');
    expect(CrowdRules.profileForScore(6), 'Dynamique');
    final id = await addProject();
    expect(
      await CrowdRules.remainingAllowance(id, investorA.email),
      CrowdRules.standardLimit,
    );
    final profile = await CrowdRules.saveProfile(investorA.email, [0, 0, 1]);
    expect(profile.name, 'Prudent');
    await invest(id, investorA, 300, 30);
    expect(await CrowdRules.remainingAllowance(id, investorA.email), 700);
  });

  test('8. l’attestation est un vrai fichier PDF', () async {
    final bytes = await buildCertificatePdf(
      {
        'id': 42,
        'projectTitle': 'Projet test',
        'pack': 'Premium',
        'tokens': 55,
        'amount': 2137.5,
        'createdAt': '2026-11-02T10:00:00',
      },
      holderName: 'Alice Martin',
      holderEmail: investorA.email,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(certificateNumber({'id': 42}), 'CT-ATT-000042');
  });

  test('9. tableau de bord : montant collecté par jour', () {
    final now = DateTime.now();
    final daily = dailyAmounts([
      {'amount': 100, 'createdAt': now.toIso8601String()},
      {'amount': 50, 'createdAt': now.toIso8601String()},
      {
        'amount': 30,
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      // Les reventes ne comptent pas dans la collecte.
      {'amount': 999, 'type': 'Achat', 'createdAt': now.toIso8601String()},
    ], 14);
    expect(daily, hasLength(14));
    expect(daily.last, 150);
    expect(daily[11], 30);
  });

  test(
    '10. jalons : vote des investisseurs pour débloquer les fonds',
    () async {
      final id = await addProject(raised: 1000);
      await invest(id, investorA, 600, 60);
      await invest(id, investorB, 400, 40);
      await CrowdRules.addMilestone(id, title: 'Prototype', percent: 40);
      await expectLater(
        CrowdRules.addMilestone(id, title: 'Trop gros', percent: 70),
        throwsA(isA<RuleException>()),
      );
      final milestone = (await CrowdRules.milestonesFor(id)).single;
      final milestoneId = milestone['id']! as int;
      await CrowdRules.requestRelease(milestoneId);

      await expectLater(
        CrowdRules.vote(milestoneId, 'intrus@example.com', approve: true),
        throwsA(isA<RuleException>()),
      );
      expect(
        await CrowdRules.vote(milestoneId, investorA.email, approve: true),
        'Vote en cours',
      );
      await expectLater(
        CrowdRules.vote(milestoneId, investorA.email, approve: true),
        throwsA(isA<RuleException>()),
      );
      expect(
        await CrowdRules.vote(milestoneId, investorB.email, approve: true),
        'Débloqué',
      );
    },
  );

  test('10 bis. pas de déblocage avant que l’objectif soit atteint', () async {
    final id = await addProject(raised: 200);
    await CrowdRules.addMilestone(id, title: 'Étape 1', percent: 50);
    final milestone = (await CrowdRules.milestonesFor(id)).single;
    await expectLater(
      CrowdRules.requestRelease(milestone['id']! as int),
      throwsA(isA<RuleException>()),
    );
  });

  test('11. revente : les jetons passent du vendeur à l’acheteur', () async {
    final id = await addProject(raised: 500);
    await invest(id, investorA, 500, 50);
    CrowdTechSession.start(investorA);
    await expectLater(
      CrowdRules.createListing(id, tokens: 80, pricePerToken: 12),
      throwsA(isA<RuleException>()),
    );
    await CrowdRules.createListing(id, tokens: 20, pricePerToken: 12);
    expect(await CrowdRules.availableTokens(id, investorA.email), 30);
    final listing = (await CrowdRules.openListings()).single;
    final listingId = listing['id']! as int;
    await expectLater(
      CrowdRules.buyListing(listingId, investorA.email),
      throwsA(isA<RuleException>()),
    );
    await CrowdRules.buyListing(listingId, investorB.email);

    final seller = await CrowdRules.activeInvestments(
      projectId: id,
      ownerKey: investorA.email,
    );
    final buyer = await CrowdRules.activeInvestments(
      projectId: id,
      ownerKey: investorB.email,
    );
    expect(CrowdRules.sumTokens(seller), 30);
    expect(CrowdRules.sumTokens(buyer), 20);
    expect(CrowdRules.sumAmount(buyer), 240);
    expect(await CrowdRules.openListings(), isEmpty);
    // La collecte du projet ne change pas.
    expect(
      (await CrowdTechDatabase.getItems('funding')).single['amountRaised'],
      500,
    );
  });

  test('12. parrainage : code, filleul et bonus de jetons', () async {
    await CrowdTechDatabase.insertItem('accounts', {'email': investorA.email});
    final code = CrowdRules.referralCodeFor(investorA.email);
    expect(code, matches(RegExp(r'^CT-[0-9A-F]{6}$')));
    expect(await CrowdRules.referrerFor(code.toLowerCase()), investorA.email);
    expect(await CrowdRules.referrerFor('CT-000000'), isNull);
    await expectLater(
      CrowdRules.recordReferral(
        referrerKey: investorA.email,
        refereeKey: investorA.email,
      ),
      throwsA(isA<RuleException>()),
    );

    await CrowdRules.recordReferral(
      referrerKey: investorA.email,
      refereeKey: investorB.email,
    );
    expect(await CrowdRules.availableBonuses(investorA.email), 1);
    expect(await CrowdRules.availableBonuses(investorB.email), 1);
    // 10 % de 25 jetons = 2,5 → 3 jetons offerts, une seule fois.
    expect(await CrowdRules.consumeReferralBonus(investorB.email, 25), 3);
    expect(await CrowdRules.consumeReferralBonus(investorB.email, 25), 0);
    expect(await CrowdRules.availableBonuses(investorA.email), 1);
  });

  testWidgets('un projet en attente est caché aux autres et ❤️ fonctionne', (
    tester,
  ) async {
    useTallScreen(tester);
    await addProject();
    await CrowdTechDatabase.insertItem('funding', {
      'title': 'Projet secret',
      'company': 'Société',
      'amountRaised': 0.0,
      'goal': 1000.0,
      'tokenPrice': 10.0,
      'progress': 0,
      'feature': 'Fonction',
      'ownerKey': owner.email,
      'approval': ProjectApproval.pending,
    });
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    unawaited(navigator.pushNamed('/funding', arguments: investorA));
    await tester.pumpAndSettle();
    expect(find.text('Projet secret'), findsNothing);
    final heart = find.byTooltip('Suivre le projet').first;
    await tester.scrollUntilVisible(
      heart,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(await CrowdRules.favoriteIds(investorA.email), hasLength(1));

    navigator.pop();
    await tester.pumpAndSettle();
    unawaited(navigator.pushNamed('/funding', arguments: owner));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Projet secret'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Projet secret'), findsOneWidget);
    expect(find.text('En attente de validation'), findsWidgets);
  });
}
