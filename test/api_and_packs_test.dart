import 'dart:convert';

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/presentation/event_management_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_pack_management_page.dart';
import 'package:crowdtech/modules/news/presentation/article_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_helpers.dart';

http.Response jsonResponse(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

final fakeServer = MockClient((request) async {
  final path = request.url.path;
  return switch (request.url.host) {
    'hacker-news.firebaseio.com' when path.endsWith('topstories.json') =>
      jsonResponse([1, 2]),
    'hacker-news.firebaseio.com' => jsonResponse({
      'title': 'Story ${path.contains('/1.') ? 'A' : 'B'}',
      'score': 400,
      'url': 'https://example.com',
    }),
    'api.github.com' => jsonResponse({
      'items': [
        {
          'name': 'awesome-ai',
          'owner': {'login': 'octo'},
          'stargazers_count': 50000,
          'description': 'Outils IA',
        },
      ],
    }),
    'dummyjson.com' => jsonResponse({
      'products': [
        {'title': 'Phone ${path.split('/').last}', 'price': 299, 'rating': 4.5},
      ],
    }),
    'geocoding-api.open-meteo.com' =>
      request.url.queryParameters['name'] == 'Paris'
          ? jsonResponse({
              'results': [
                {'country': 'France', 'latitude': 48.85, 'longitude': 2.35},
              ],
            })
          : jsonResponse({}),
    _ => http.Response('not found', 404),
  };
});

void main() {
  setUp(() async {
    CrowdTechApi.client = fakeServer;
    await CrowdTechDatabase.useMemoryForTesting();
    CrowdTechSession.start(testAdmin);
  });

  test('les réponses HTTP sont converties pour chaque module', () async {
    final news = await CrowdTechApi.fetchTechNews(limit: 2);
    expect(news.map((item) => item['title']), ['Story A', 'Story B']);
    expect(news.first['credibility'], 80);

    final projects = await CrowdTechApi.fetchFundingProjects();
    expect(projects.single['title'], 'awesome-ai');
    expect(projects.single['company'], 'octo');
    expect(projects.single['goal'], 100000.0);

    final products = await CrowdTechApi.fetchProducts();
    expect(products.map((item) => item['category']), [
      'Portable',
      'Smartphone',
    ]);

    expect((await CrowdTechApi.geocodeCity('Paris'))?['country'], 'France');
    expect(await CrowdTechApi.geocodeCity('Nullepart'), isNull);
  });

  test('un serveur en erreur produit une ApiException', () async {
    CrowdTechApi.client = MockClient((_) async => http.Response('', 500));
    expect(CrowdTechApi.fetchTechNews(), throwsA(isA<ApiException>()));
  });

  test('l’import SQLite ignore les doublons', () async {
    final news = await CrowdTechApi.fetchTechNews(limit: 2);
    expect(
      await CrowdTechDatabase.importItems('news', news, uniqueKey: 'title'),
      2,
    );
    expect(
      await CrowdTechDatabase.importItems('news', news, uniqueKey: 'title'),
      0,
    );
    expect(await CrowdTechDatabase.getItems('news'), hasLength(2));
  });

  testWidgets('la gestion des actualités importe depuis Internet', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ArticleManagementPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Importer depuis Internet'));
    await tester.pumpAndSettle();
    expect(find.text('Story A'), findsOneWidget);
    expect(find.textContaining('importée(s) depuis Hacker News'), findsOne);
  });

  testWidgets('la gestion des événements vérifie les villes', (tester) async {
    await CrowdTechDatabase.insertItem('events', {
      'title': 'Forum',
      'date': '12 Nov 2026',
      'city': 'Paris',
      'seats': 10,
    });
    await tester.pumpWidget(const MaterialApp(home: EventManagementPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vérifier les villes sur Internet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paris (France)'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('events')).single['latitude'],
      48.85,
    );
  });

  testWidgets('CRUD des packs de jetons dans SQLite', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TokenPackManagementPage()));
    await tester.pumpAndSettle();
    expect(find.text('Pack Découverte'), findsOneWidget);

    // Créer
    await tester.tap(find.text('Nouveau pack'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Étudiant');
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), '200');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Valeur entre 0 et 100.'), findsOneWidget);
    await tester.enterText(fields.at(2), '15');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Pack Étudiant'), findsOneWidget);

    // Supprimer
    final tile = find.ancestor(
      of: find.text('Pack Étudiant'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Pack Étudiant'), findsNothing);
    expect(await CrowdTechDatabase.getItems('token_packs'), hasLength(4));
  });
}
