// Tests des fonctionnalités du cahier des charges ajoutées : modération,
// recherche par confiance, features par seuils, devises, escrow, réputation,
// filtres, badges signés, file d'attente, rappels, Firebase REST.

import 'dart:convert';

import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/core/firebase/firebase_rest.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/funding/domain/currency_service.dart';
import 'package:crowdtech/modules/funding/domain/feature_unlock.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/modules/funding/domain/project_feature.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';
import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/modules/marketplace/domain/product_search.dart';
import 'package:crowdtech/modules/marketplace/domain/seller_reputation.dart';
import 'package:crowdtech/modules/news/domain/comment_moderation.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/modules/news/domain/news_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void login(String email, [String role = UserRoles.reader]) =>
    CrowdTechSession.start(CrowdUser(name: email, email: email, role: role));

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() async {
    CrowdTechSession.clear();
    FirebaseRest.enabledOverride = null;
    await CrowdTechDatabase.useMemoryForTesting();
  });

  group('Actus : modération et recherche', () {
    test('insultes masquées, spam et majuscules refusés', () {
      final masked = CommentModeration.analyze('Quel idiot ce titre');
      expect(masked.verdict, ModerationVerdict.masked);
      expect(masked.text, 'Quel ***** ce titre');
      expect(
        CommentModeration.analyze('Cliquez ici pour gagner').accepted,
        isFalse,
      );
      expect(
        CommentModeration.analyze('CET ARTICLE EST FAUX ET NUL').accepted,
        isFalse,
      );
      expect(CommentModeration.analyze('Trèèèèèèèès bien').accepted, isFalse);
      expect(
        CommentModeration.analyze('Bonne analyse, merci !').verdict,
        ModerationVerdict.approved,
      );
    });

    test('masquage automatique au 3e signalement', () async {
      login('auteur@x.com');
      final comment = await NewsFeedback.addComment(
        articleId: 1,
        articleTitle: 'Article',
        ownerKey: 'auteur@x.com',
        text: 'Mon avis sur cet article',
      );
      expect(
        () => CommentModeration.report(comment.id!),
        throwsA(isA<RuleException>()),
      );
      for (final reader in ['a@x.com', 'b@x.com', 'c@x.com']) {
        login(reader);
        await CommentModeration.report(comment.id!);
      }
      final saved = (await CrowdTechDatabase.getItems('news_comments')).single;
      expect(saved['status'], CommentStatus.hidden);
      login('c@x.com');
      expect(
        () => CommentModeration.report(comment.id!),
        throwsA(isA<RuleException>()),
      );
      login('admin@x.com', UserRoles.admin);
      await CommentModeration.restore(comment.id!);
      expect(
        (await CrowdTechDatabase.getItems('news_comments')).single['status'],
        CommentStatus.visible,
      );
    });

    test('commentaire spam refusé à la publication', () {
      expect(
        NewsFeedback.addComment(
          articleId: 1,
          articleTitle: 'A',
          ownerKey: 'x@x.com',
          text: 'free money click here',
        ),
        throwsA(isA<RuleException>()),
      );
    });

    test('recherche indexée, filtrée et classée par fiabilité', () {
      const items = [
        NewsItem(
          id: 1,
          title: 'Crypto : nouvelle régulation',
          source: 'Blog',
          credibility: 40,
          tag: 'Finance',
          summary: 'Rumeurs',
        ),
        NewsItem(
          id: 2,
          title: 'La cryptographie post-quantique',
          source: 'IEEE',
          credibility: 90,
          tag: 'Sécurité',
          summary: 'Standards',
        ),
        NewsItem(
          id: 3,
          title: 'Nouvelles puces IA',
          source: 'Presse',
          credibility: 60,
          tag: 'Matériel',
          summary: 'Crypto absente',
        ),
      ];
      final results = NewsSearch.search(items, query: 'crypt');
      // Début de mot trouvé ; la source fiable passe devant.
      expect(results.map((item) => item.id), [2, 1, 3]);
      expect(
        NewsSearch.search(items, level: TrustLevel.high).map((item) => item.id),
        [2],
      );
      expect(
        NewsSearch.search(items, level: TrustLevel.low).map((item) => item.id),
        [1],
      );
      expect(
        NewsSearch.search(
          items,
          sort: NewsSort.credibility,
        ).map((item) => item.id),
        [2, 3, 1],
      );
      expect(NewsSearch.search(items, query: 'inexistant'), isEmpty);
    });
  });

  group('Crowdfunding : features, prix et portefeuille', () {
    test('déblocage séquentiel par seuils de jetons', () {
      const features = [
        ProjectFeature(projectId: 1, title: 'A', tokenThreshold: 100, rank: 1),
        ProjectFeature(projectId: 1, title: 'B', tokenThreshold: 300, rank: 2),
        ProjectFeature(projectId: 1, title: 'C', tokenThreshold: 600, rank: 3),
      ];
      final states = FeatureUnlock.evaluate(features, 200);
      expect(states.map((s) => s.state), [
        FeatureState.unlocked,
        FeatureState.next,
        FeatureState.locked,
      ]);
      expect(states[1].missingTokens, 100);
      expect(states[1].progress, closeTo(0.5, 1e-9));
      expect(
        FeatureUnlock.evaluate(
          features,
          700,
        ).every((s) => s.state == FeatureState.unlocked),
        isTrue,
      );
    });

    test('seuils croissants et atteignables, déblocage enregistré', () async {
      login('owner@x.com', UserRoles.projectOwner);
      final projectId = await CrowdTechDatabase.insertItem('funding', {
        'title': 'Drone',
        'company': 'Sky',
        'amountRaised': 0.0,
        'goal': 10000.0,
        'tokenPrice': 10.0,
        'progress': 0,
        'feature': 'Vol autonome',
        'ownerKey': 'owner@x.com',
      });
      final project = FundingProject.fromMap({
        'id': projectId,
        ...(await CrowdTechDatabase.getItems('funding')).single,
      });
      await FeatureUnlock.addFeature(
        project,
        title: 'Prototype',
        tokenThreshold: 50,
      );
      expect(
        FeatureUnlock.addFeature(project, title: 'Bis', tokenThreshold: 40),
        throwsA(isA<RuleException>()),
      );
      expect(
        FeatureUnlock.addFeature(project, title: 'Trop', tokenThreshold: 5000),
        throwsA(isA<RuleException>()),
      );
      await CrowdTechDatabase.insertItem('investments', {
        'projectId': projectId,
        'tokens': 60,
        'amount': 600.0,
        'ownerKey': 'fan@x.com',
      });
      expect(await FeatureUnlock.refreshUnlocks(projectId), ['Prototype']);
      expect(await FeatureUnlock.refreshUnlocks(projectId), isEmpty);
    });

    test('prix suggéré, conversion et jetons pour un budget', () {
      expect(TokenPricing.suggestedPrice(42000), 50);
      expect(TokenPricing.supply(42000, 50), 840);
      final rates = ExchangeRates(const {'TND': 3.4}, 'test', DateTime(2026));
      expect(CurrencyService.convert(10, 'EUR', 'TND', rates), 34);
      final result = TokenPricing.tokensForBudget(
        budget: 100,
        currency: 'TND',
        tokenPriceEur: 10,
        rates: rates,
      );
      expect(result.tokens, 2);
      expect(result.change, closeTo(32, 1e-9));
    });

    test('taux ExchangeRate-API mis en cache, secours hors ligne', () async {
      CrowdTechApi.client = MockClient(
        (request) async => request.url.host == 'open.er-api.com'
            ? json({
                'result': 'success',
                'rates': {'TND': 3.3, 'USD': 1.1, 'JPY': 160},
              })
            : http.Response('', 404),
      );
      final live = await CurrencyService.load();
      expect(live.source, 'ExchangeRate-API');
      expect(live.rateOf('TND'), 3.3);
      expect(live.rates.containsKey('JPY'), isFalse);
      CrowdTechApi.client = MockClient((_) async => http.Response('', 500));
      expect((await CurrencyService.load()).source, 'cache');
      await CrowdTechDatabase.useMemoryForTesting();
      expect((await CurrencyService.load()).source, 'taux de secours');
    });

    test('évolution du portefeuille par jour', () {
      final points = PortfolioAnalytics.evolution([
        {'amount': 100, 'tokens': 10, 'createdAt': '2026-01-01T10:00:00'},
        {'amount': 50, 'tokens': 5, 'createdAt': '2026-01-01T18:00:00'},
        {
          'amount': 999,
          'tokens': 99,
          'status': 'Remboursé',
          'createdAt': '2026-01-02T10:00:00',
        },
        {'amount': 25, 'tokens': 2, 'createdAt': '2026-01-03T10:00:00'},
      ]);
      expect(points.map((p) => p.invested), [150, 175]);
      expect(points.last.tokens, 17);
      expect(PortfolioAnalytics.projectedValue(100, 10, 2), closeTo(121, 1e-9));
      final config = PortfolioAnalytics.chartConfig(points);
      expect((config['data']! as Map)['labels'], hasLength(5));
      expect(
        CrowdTechApi.quickChartUrl(config),
        startsWith('https://quickchart.io/chart?'),
      );
    });
  });

  group('Marketplace : escrow, réputation, filtres', () {
    Future<int> order({String status = OrderState.held}) async {
      final productId = await CrowdTechDatabase.insertItem('products', {
        'name': 'Casque',
        'price': 50.0,
        'stock': 3,
        'category': 'Audio',
        'ownerKey': 'seller@x.com',
      });
      return CrowdTechDatabase.insertItem('orders', {
        'ownerKey': 'buyer@x.com',
        'sellerKeys': ['seller@x.com'],
        'items': [
          {'productId': productId, 'quantity': 2},
        ],
        'total': 100.0,
        'status': status,
      });
    }

    test('parcours escrow et droits de chaque rôle', () async {
      final id = await order();
      login('buyer@x.com');
      var current = (await CrowdTechDatabase.getItems('orders')).single;
      expect(OrderEscrow.availableActions(current, 'buyer@x.com'), [
        OrderAction.cancel,
      ]);
      expect(
        OrderEscrow.apply(id, OrderAction.ship),
        throwsA(isA<RuleException>()),
      );
      login('seller@x.com');
      await OrderEscrow.apply(id, OrderAction.ship);
      login('buyer@x.com');
      expect(
        OrderEscrow.apply(id, OrderAction.dispute, note: 'ko'),
        throwsA(isA<RuleException>()),
      );
      await OrderEscrow.apply(id, OrderAction.confirm);
      current = (await CrowdTechDatabase.getItems('orders')).single;
      expect(current['status'], OrderState.completed);
      expect(current['history'], hasLength(2));
      expect(
        OrderEscrow.apply(id, OrderAction.cancel),
        throwsA(isA<RuleException>()),
      );
    });

    test('annulation et remboursement remettent le stock', () async {
      final id = await order();
      login('buyer@x.com');
      await OrderEscrow.apply(id, OrderAction.cancel);
      final product = (await CrowdTechDatabase.getItems('products')).single;
      expect(product['stock'], 5);
    });

    test('libération automatique après le délai de protection', () async {
      await order(status: OrderState.shipped);
      final row = (await CrowdTechDatabase.getItems('orders')).single;
      await CrowdTechDatabase.updateItem(
        'orders',
        row['id']! as int,
        {...row, 'shippedAt': DateTime(2026).toIso8601String()}..remove('id'),
      );
      expect(await OrderEscrow.autoRelease(now: DateTime(2026, 1, 10)), 0);
      expect(await OrderEscrow.autoRelease(now: DateTime(2026, 1, 20)), 1);
      expect(
        (await CrowdTechDatabase.getItems('orders')).single['status'],
        OrderState.completed,
      );
    });

    test('réputation bayésienne et avis après commande terminée', () async {
      final id = await order(status: OrderState.completed);
      final completed = (await CrowdTechDatabase.getItems('orders')).single;
      login('intrus@x.com');
      expect(
        SellerReputationService.review(
          order: completed,
          sellerKey: 'seller@x.com',
          stars: 5,
        ),
        throwsA(isA<RuleException>()),
      );
      login('buyer@x.com');
      await SellerReputationService.review(
        order: completed,
        sellerKey: 'seller@x.com',
        stars: 5,
      );
      expect(
        SellerReputationService.review(
          order: completed,
          sellerKey: 'seller@x.com',
          stars: 4,
        ),
        throwsA(isA<RuleException>()),
      );
      final rep = await SellerReputationService.load('seller@x.com');
      expect(rep.reviewCount, 1);
      // 1 seul avis 5★ : moyenne ramenée vers 3,5.
      expect(rep.weightedStars, closeTo((5 + 3.5 * 3) / 4, 1e-9));
      expect(rep.completedOrders, 1);
      expect(id, isPositive);

      final many = SellerReputationService.compute(
        's',
        [
          for (var i = 0; i < 20; i++) {'sellerKey': 's', 'stars': 5},
        ],
        [
          for (var i = 0; i < 10; i++)
            {
              'sellerKey': 's',
              'sellerKeys': ['s'],
              'status': OrderState.completed,
            },
        ],
      );
      expect(many.level, 'Top vendeur');
      expect(rep.score, lessThan(many.score));
    });

    test('filtres multi-critères et tris', () {
      const products = [
        ProductItem(
          id: 1,
          name: 'Laptop Pro',
          price: 1500,
          category: 'Portable',
          brand: 'Edge',
          rating: 4.8,
          stock: 2,
          ownerKey: 'a',
        ),
        ProductItem(
          id: 2,
          name: 'Laptop Eco',
          price: 600,
          category: 'Portable',
          brand: 'Lite',
          rating: 4.0,
          stock: 0,
          condition: 'Reconditionné',
          ownerKey: 'b',
        ),
        ProductItem(
          id: 3,
          name: 'Casque',
          price: 90,
          category: 'Audio',
          brand: 'Edge',
          rating: 4.5,
          stock: 5,
          ownerKey: 'b',
        ),
      ];
      List<int?> ids(ProductFilter filter) => ProductSearch.apply(
        products,
        filter,
        sellerScores: const {'a': 90, 'b': 40},
      ).map((p) => p.id).toList();
      expect(ids(const ProductFilter(query: 'laptop')), [1, 2]);
      expect(ids(const ProductFilter(brands: {'Edge'})), [1, 3]);
      expect(ids(const ProductFilter(maxPrice: 700)), [2, 3]);
      expect(ids(const ProductFilter(inStockOnly: true)), [1, 3]);
      expect(ids(const ProductFilter(conditions: {'Reconditionné'})), [2]);
      expect(ids(const ProductFilter(minRating: 4.5)), [1, 3]);
      expect(ids(const ProductFilter(minSellerScore: 60)), [1]);
      expect(ids(const ProductFilter(sort: ProductSort.priceAsc)), [3, 2, 1]);
      expect(
        const ProductFilter(maxPrice: 1, inStockOnly: true).activeCount,
        2,
      );
    });
  });

  group('Événements : badges, file d’attente, rappels', () {
    test('badge signé : valide une fois, falsification détectée', () async {
      final badge = AccessBadge.issue(
        ticket: 'CT-1',
        eventId: 7,
        email: 'ada@x.com',
        eventDate: '12/03/2099',
      );
      expect(AccessBadge.isAuthentic(badge), isTrue);
      expect(AccessBadge.decode(badge)!.eventId, 7);
      final parts = badge.split('.');
      final forged = '${parts[0]}.${parts[1]}.${'0' * parts[2].length}';
      expect(AccessBadge.isAuthentic(forged), isFalse);

      await CrowdTechDatabase.insertItem('reservations', {
        'eventId': 7,
        'ticket': 'CT-1',
        'attendeeName': 'Ada',
        'badge': badge,
      });
      expect((await AccessBadge.checkIn(forged)).valid, isFalse);
      final first = await AccessBadge.checkIn(badge);
      expect(first.valid, isTrue);
      expect(first.message, 'Entrée validée : Ada.');
      expect((await AccessBadge.checkIn(badge)).message, contains('déjà'));
      expect(
        (await AccessBadge.checkIn(badge, now: DateTime(2100))).message,
        contains('expiré'),
      );
    });

    test('file d’attente : promotion automatique à l’annulation', () async {
      final eventId = await CrowdTechDatabase.insertItem('events', {
        'title': 'Forum',
        'date': '12/03/2099',
        'city': 'Tunis',
        'seats': 1,
      });
      final event = {
        'id': eventId,
        ...(await CrowdTechDatabase.getItems('events')).single,
      };
      login('ada@x.com');
      final booking = await EventCapacity.book(
        event: event,
        accountKey: 'ada@x.com',
        name: 'Ada',
        email: 'ada@x.com',
      );
      expect(booking['badge'], startsWith('CTB2.'));
      expect(
        EventCapacity.book(
          event: event,
          accountKey: 'bob@x.com',
          name: 'Bob',
          email: 'bob@x.com',
        ),
        throwsA(isA<RuleException>()),
      );
      expect(
        await EventCapacity.joinWaitlist(
          event: event,
          accountKey: 'bob@x.com',
          name: 'Bob',
          email: 'bob@x.com',
        ),
        1,
      );
      expect(
        await EventCapacity.joinWaitlist(
          event: event,
          accountKey: 'eve@x.com',
          name: 'Eve',
          email: 'eve@x.com',
        ),
        2,
      );
      expect(
        await EventCapacity.cancelReservation(booking['id']! as int),
        'Bob',
      );
      final active = await EventCapacity.activeReservations(eventId);
      expect(active.single['ownerKey'], 'bob@x.com');
      expect(await EventCapacity.positionOf(eventId, 'eve@x.com'), 1);
      expect(await Reminders.unreadCount('bob@x.com'), 1);
    });

    test('rappels J-7, J-1 et jour J, une seule fois chacun', () async {
      await CrowdTechDatabase.insertItem('reservations', {
        'eventTitle': 'Salon',
        'date': '20/06/2026',
        'ownerKey': 'ada@x.com',
        'status': ReservationStatus.booked,
      });
      expect(await Reminders.generate('ada@x.com', now: DateTime(2026, 6)), 0);
      expect(
        await Reminders.generate('ada@x.com', now: DateTime(2026, 6, 14)),
        1,
      );
      expect(
        await Reminders.generate('ada@x.com', now: DateTime(2026, 6, 14)),
        0,
      );
      // J-1 arrivé : seul le rappel « demain » est ajouté.
      expect(
        await Reminders.generate('ada@x.com', now: DateTime(2026, 6, 19, 9)),
        1,
      );
      expect(
        await Reminders.generate('ada@x.com', now: DateTime(2026, 6, 20, 8)),
        1,
      );
      final titles = (await Reminders.of('ada@x.com')).map((r) => r['title']);
      expect(titles, contains('⏰ Salon demain'));
      await Reminders.markAllRead('ada@x.com');
      expect(await Reminders.unreadCount('ada@x.com'), 0);
    });

    test('Nominatim, QR et tuile OpenStreetMap', () async {
      CrowdTechApi.client = MockClient(
        (request) async => request.url.host == 'nominatim.openstreetmap.org'
            ? json([
                {
                  'lat': '36.8',
                  'lon': '10.18',
                  'display_name': 'Tunis',
                  'address': {'country': 'Tunisie'},
                },
              ])
            : http.Response('', 404),
      );
      final place = await CrowdTechApi.geocodeCity('Tunis');
      expect(place?['country'], 'Tunisie');
      expect(place?['latitude'], 36.8);
      expect(CrowdTechApi.qrCodeUrl('CTB1.x'), contains('api.qrserver.com'));
      final tile = CrowdTechApi.osmTile(48.8584, 2.2945);
      expect(tile.url, 'https://tile.openstreetmap.org/15/16592/11272.png');
      expect(tile.x, inInclusiveRange(0, 1));
    });
  });

  group('Firebase REST (plan Spark)', () {
    test('conversion des valeurs Firestore aller-retour', () {
      final value = {
        'name': 'Ada',
        'stars': 5,
        'price': 9.5,
        'ok': true,
        'tags': ['a', 'b'],
        'nested': {'x': null},
      };
      final encoded = FirebaseRest.encodeValue(value);
      expect(FirebaseRest.decodeValue(encoded), value);
    });

    test('inscription Firebase et erreurs traduites', () async {
      final requests = <Uri>[];
      FirebaseRest.client = MockClient((request) async {
        requests.add(request.url);
        final body = jsonDecode(request.body) as Map;
        return body['email'] == 'pris@x.com'
            ? json({
                'error': {'message': 'EMAIL_EXISTS'},
              }, 400)
            : json({'idToken': 'jeton', 'localId': 'uid1'});
      });
      await FirebaseRest.signUp('ada@x.com', 'secret123');
      expect(FirebaseRest.idToken, 'jeton');
      expect(requests.single.path, '/v1/accounts:signUp');
      expect(
        FirebaseRest.signUp('pris@x.com', 'secret123'),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.message,
            'message',
            'Un compte existe déjà avec cet email.',
          ),
        ),
      );
      FirebaseRest.signOut();
      expect(FirebaseRest.idToken, isNull);
    });
  });
}
