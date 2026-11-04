import 'dart:async';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/presentation/token_pack_management_page.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:crowdtech/modules/news/presentation/article_management_page.dart';
import 'package:crowdtech/modules/profile/presentation/admin_roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const investor = CrowdUser(
  name: 'Inès',
  email: 'ines@example.com',
  role: UserRoles.investor,
);

void main() {
  setUp(() async {
    await CrowdTechDatabase.useMemoryForTesting();
    CrowdTechSession.clear();
  });

  group('Comptes et rôles', () {
    test('le compte administrateur par défaut existe et se connecte', () async {
      final admin = await AccountService.login(
        email: AccountService.defaultAdminEmail,
        password: AccountService.defaultAdminPassword,
      );
      expect(admin.role, UserRoles.admin);
    });

    test('impossible de s’inscrire directement comme administrateur', () async {
      final user = await AccountService.register(
        name: 'Pirate',
        email: 'pirate@example.com',
        password: 'secret123',
        role: UserRoles.admin,
      );
      expect(user.role, UserRoles.reader);
    });

    test('seul l’administrateur peut changer un rôle', () async {
      await AccountService.register(
        name: 'Inès',
        email: 'ines@example.com',
        password: 'secret123',
        role: UserRoles.reader,
      );
      // Inès (connectée) essaie de se promouvoir : refusé.
      await expectLater(
        AccountService.changeRole('ines@example.com', UserRoles.admin),
        throwsA(isA<AccountException>()),
      );
      // L'administrateur peut le faire.
      await AccountService.login(
        email: AccountService.defaultAdminEmail,
        password: AccountService.defaultAdminPassword,
      );
      await AccountService.changeRole('ines@example.com', UserRoles.investor);
      final ines = await AccountService.login(
        email: 'ines@example.com',
        password: 'secret123',
      );
      expect(ines.role, UserRoles.investor);
    });
  });

  group('Pages réservées', () {
    testWidgets('un non-admin ne peut pas gérer les packs ni les rôles', (
      tester,
    ) async {
      CrowdTechSession.start(investor);
      await tester.pumpWidget(
        const MaterialApp(home: TokenPackManagementPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accès réservé à l’administrateur.'), findsOneWidget);
      expect(find.text('Nouveau pack'), findsNothing);

      await tester.pumpWidget(const MaterialApp(home: AdminRolesPage()));
      await tester.pumpAndSettle();
      expect(find.text('Accès réservé à l’administrateur.'), findsOneWidget);
    });

    testWidgets(
      'Crowd : pas de bouton + ni de menu packs pour un investisseur',
      (tester) async {
        useTallScreen(tester);
        await tester.pumpWidget(const CrowdTechApp());
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        unawaited(navigator.pushNamed('/funding', arguments: investor));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ajouter un projet'), findsNothing);
        await tester.tap(find.byTooltip('Autres pages crowdfunding'));
        await tester.pumpAndSettle();
        expect(find.text('Gérer les packs de jetons'), findsNothing);
        expect(find.text('Gérer mes projets'), findsOneWidget);
      },
    );

    testWidgets('la gestion n’affiche que ses propres éléments', (
      tester,
    ) async {
      await CrowdTechDatabase.insertItem('news', {
        'title': 'Article d’Inès',
        'source': 'S',
        'credibility': 0,
        'tag': 'IA',
        'summary': 'Résumé de l’article.',
        'ownerKey': investor.email,
      });
      await CrowdTechDatabase.insertItem('news', {
        'title': 'Article de quelqu’un d’autre',
        'source': 'S',
        'credibility': 0,
        'tag': 'IA',
        'summary': 'Résumé de l’article.',
        'ownerKey': 'autre@example.com',
      });
      CrowdTechSession.start(investor);
      await tester.pumpWidget(const MaterialApp(home: ArticleManagementPage()));
      await tester.pumpAndSettle();
      expect(find.text('Article d’Inès'), findsOneWidget);
      expect(find.text('Article de quelqu’un d’autre'), findsNothing);
      expect(find.byTooltip('Importer depuis Internet'), findsNothing);
    });
  });

  group('Logique métier', () {
    test('une commande ne vide que le panier de l’acheteur', () async {
      await CrowdTechDatabase.insertItem('cart', {
        'productId': 1,
        'productName': 'A',
        'quantity': 1,
        'ownerKey': 'ines@example.com',
      });
      await CrowdTechDatabase.insertItem('cart', {
        'productId': 2,
        'productName': 'B',
        'quantity': 1,
        'ownerKey': 'autre@example.com',
      });
      await CrowdTechDatabase.createOrderAndClearCart({
        'ownerKey': 'ines@example.com',
        'items': const [],
        'total': 10.0,
      });
      final cart = await CrowdTechDatabase.getItems('cart');
      expect(cart.single['ownerKey'], 'autre@example.com');
    });

    test(
      'une seule note par utilisateur : noter à nouveau la modifie',
      () async {
        final id = await CrowdTechDatabase.insertItem('news', {
          'title': 'Article noté',
          'source': 'S',
          'credibility': 96,
          'tag': 'IA',
          'summary': 'Résumé de l’article.',
        });
        Future<void> rate(String owner, int stars, [String review = '']) =>
            NewsFeedback.saveReview(
              articleId: id,
              articleTitle: 'Article noté',
              ownerKey: owner,
              stars: stars,
              review: review,
            );

        await rate(investor.email, 5, 'Très fiable.');
        await rate(investor.email, 2);
        await rate('autre@example.com', 4);

        final votes = await CrowdTechDatabase.getItems('news_votes');
        expect(votes, hasLength(2));
        final mine = votes.singleWhere((v) => v['ownerKey'] == investor.email);
        expect(mine['stars'], 2);
        expect(mine['review'], '');
        // Moyenne (2 + 4) / 2 = 3 étoiles → 60 %, pondérée par la source (96 %,
        // poids 3) : (96×3 + 60×2) / 5 = 82 %.
        final article = (await CrowdTechDatabase.getItems('news')).single;
        expect(article['credibility'], 82);
        expect(article['sourceCredibility'], 96);
        expect(() => rate(investor.email, 6), throwsA(isA<ArgumentError>()));
      },
    );

    testWidgets('« Réservé » ne concerne que mes propres réservations', (
      tester,
    ) async {
      useTallScreen(tester);
      await CrowdTechDatabase.loadSeededItems('events', const [
        {'title': 'Forum', 'date': '12/12/2030', 'city': 'Tunis', 'seats': 10},
      ]);
      await CrowdTechDatabase.insertItem('reservations', {
        'eventId': 1,
        'eventTitle': 'Forum',
        'attendeeName': 'Autre',
        'ownerKey': 'autre@example.com',
        'ticket': 'CT-1',
      });
      await tester.pumpWidget(const CrowdTechApp());
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(navigator.pushNamed('/events', arguments: investor));
      await tester.pumpAndSettle();
      expect(find.text('Réserver'), findsOneWidget);
      expect(find.text('9 places restantes'), findsOneWidget);
    });
  });
}
