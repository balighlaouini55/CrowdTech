// Assistant Crowdy : filtre de sujet, appel à Gemini et mode hors ligne.

import 'dart:async';
import 'dart:convert';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/domain/crowd_assistant.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_helpers.dart';

const crowd = CrowdContext(
  projects: [
    FundingProject(
      title: 'AI Ops Dashboard',
      company: 'NovaStack',
      amountRaised: 42000,
      goal: 80000,
      tokenPrice: 45,
      progress: 52,
      feature: 'Automatiser',
      category: 'IA',
    ),
    FundingProject(
      title: 'Green Pulse Sensor',
      company: 'EcoByte',
      amountRaised: 65000,
      goal: 95000,
      tokenPrice: 30,
      progress: 68,
      feature: 'Capteurs',
      category: 'Green tech',
    ),
  ],
  packs: TokenPack.defaults,
);

/// Faux serveur Gemini : liste des modèles et réponse [reply].
MockClient fakeGemini(String reply, {List<http.Request>? calls}) =>
    MockClient((request) async => fakeGeminiResponse(request, reply, calls));

/// Réponse du faux serveur Gemini à [request].
Future<http.Response> fakeGeminiResponse(
  http.Request request,
  String reply, [
  List<http.Request>? calls,
]) async {
  calls?.add(request);
  if (request.url.path.endsWith('/models')) {
    return http.Response(
      jsonEncode({
        'models': [
          for (final name in [
            'gemini-3.5-flash',
            'gemini-3.6-flash',
            'gemini-3.8-flash',
            'gemini-3.8-flash-image',
            'gemini-3.9-flash-lite',
            'gemini-3.1-pro',
          ])
            {
              'name': 'models/$name',
              'supportedGenerationMethods': ['generateContent'],
            },
        ],
      }),
      200,
    );
  }
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': reply},
              ],
            },
          },
        ],
      }),
    ),
    200,
  );
}

void main() {
  setUp(() {
    CrowdAssistant.resetModel();
    CrowdAssistant.apiKeyOverride = 'cle-de-test';
  });
  tearDown(() => CrowdAssistant.apiKeyOverride = null);

  test('le filtre reconnaît les questions du crowdfunding', () {
    expect(CrowdAssistant.isOnTopic('Quel pack choisir ?', crowd), isTrue);
    expect(CrowdAssistant.isOnTopic('Parle-moi de EcoByte', crowd), isTrue);
    expect(CrowdAssistant.isOnTopic('Est-ce risqué ?', crowd), isTrue);
    expect(CrowdAssistant.isOnTopic('Bonjour !', crowd), isTrue);
    expect(
      CrowdAssistant.isOnTopic('Donne-moi une recette de pizza', crowd),
      isFalse,
    );
    expect(
      CrowdAssistant.isOnTopic('Qui a gagné la coupe du monde 2022 ?', crowd),
      isFalse,
    );
  });

  test('les questions sur l’argent sont acceptées', () {
    for (final question in [
      'Comment gagner de l’argent ?',
      'Je veux gagner plus',
      'Où placer mes économies ?',
      'J’ai 300 euros, je fais quoi ?',
      'Combien je peux gagner ?',
      'Comment faire fructifier mon argent ?',
    ]) {
      expect(
        CrowdAssistant.isOnTopic(question, crowd),
        isTrue,
        reason: question,
      );
    }
    expect(
      CrowdAssistant.isOnTopic('Qui va gagner le match ce soir ?', crowd),
      isFalse,
    );
  });

  test('hors ligne, une question d’argent reçoit une réponse CrowdTech', () {
    final reply = CrowdAssistant.offlineAnswer(
      'Comment gagner de l’argent ?',
      crowd,
    );
    expect(reply, contains('Marché des jetons'));
    expect(reply, contains('Aucun gain n’est garanti'));
  });

  test('une question hors sujet est refusée sans appeler Gemini', () async {
    final calls = <http.Request>[];
    CrowdAssistant.client = fakeGemini('Voici la recette…', calls: calls);

    final reply = await CrowdAssistant.answer(
      'Donne-moi une recette de pizza',
      crowd,
    );

    expect(reply.text, CrowdAssistant.refusal);
    expect(calls, isEmpty);
  });

  test('une question du crowdfunding est envoyée à Gemini', () async {
    final calls = <http.Request>[];
    CrowdAssistant.client = fakeGemini(
      'Green Pulse Sensor est le plus avancé.',
      calls: calls,
    );

    final reply = await CrowdAssistant.answer(
      'Quel projet est le plus avancé ?',
      crowd,
    );

    expect(reply.text, 'Green Pulse Sensor est le plus avancé.');
    expect(reply.offline, isFalse);
    final chat = calls.last;
    // Le modèle rapide et stable est choisi en priorité.
    expect(chat.url.path, endsWith('/models/gemini-3.6-flash:generateContent'));
    expect(chat.headers['x-goog-api-key'], 'cle-de-test');
    final body = jsonDecode(chat.body) as Map<String, Object?>;
    final system =
        (((body['system_instruction']! as Map)['parts'] as List).first
                as Map)['text']
            as String;
    expect(system, contains(CrowdAssistant.refusal));
    expect(system, contains('(68 %)'));
    expect(system, contains('Le plus avancé : Green Pulse Sensor'));
    final contents = body['contents']! as List;
    expect((contents.last as Map)['role'], 'user');
    expect(
      ((body['generationConfig']! as Map)['thinkingConfig']
          as Map)['thinkingLevel'],
      'low',
    );
  });

  test('un modèle surchargé est remplacé par le suivant', () async {
    final tried = <String>[];
    CrowdAssistant.client = MockClient((request) async {
      if (request.url.path.contains(':generateContent')) {
        tried.add(request.url.pathSegments.last.split(':').first);
        if (request.url.path.contains('gemini-3.6-flash')) {
          return http.Response('{"error": {"code": 503}}', 503);
        }
      }
      return fakeGeminiResponse(request, 'Réponse du modèle de secours.');
    });

    final reply = await CrowdAssistant.answer(
      'Quels sont les risques ?',
      crowd,
    );

    expect(reply.text, 'Réponse du modèle de secours.');
    expect(reply.offline, isFalse);
    expect(tried, ['gemini-3.6-flash', 'gemini-3.8-flash']);

    // Question suivante : le modèle en panne n'est plus essayé en premier.
    tried.clear();
    await CrowdAssistant.answer('Quel pack choisir ?', crowd);
    expect(tried.first, 'gemini-3.8-flash');
  });

  test(
    'sans clé ou sans réseau, une réponse hors ligne est calculée',
    () async {
      CrowdAssistant.client = MockClient(
        (_) async => throw http.ClientException('Pas de réseau'),
      );

      final reply = await CrowdAssistant.answer(
        'Quel projet est le plus proche de son objectif ?',
        crowd,
      );

      expect(reply.offline, isTrue);
      expect(reply.text, contains('Green Pulse Sensor : 68 %'));
      expect(
        reply.text.indexOf('Green Pulse'),
        lessThan(reply.text.indexOf('AI Ops')),
      );

      CrowdAssistant.apiKeyOverride = '';
      final calls = <http.Request>[];
      CrowdAssistant.client = fakeGemini('jamais appelé', calls: calls);
      final noKey = await CrowdAssistant.answer(
        'Quels sont les risques ?',
        crowd,
      );
      expect(noKey.offline, isTrue);
      expect(calls, isEmpty);
    },
  );

  testWidgets('l’assistant s’ouvre depuis le crowdfunding et répond', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    CrowdAssistant.client = fakeGemini(
      'Le pack Booster offre des jetons bonus.',
    );
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/funding', arguments: testAdmin));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Assistant Crowdy'));
    await tester.pumpAndSettle();
    expect(find.text('Assistant Crowdy'), findsOneWidget);

    await tester.tap(find.text('Quel pack de jetons choisir ?'));
    await tester.pumpAndSettle();
    expect(
      find.text('Le pack Booster offre des jetons bonus.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      'Quelle est la capitale du Japon ?',
    );
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text(CrowdAssistant.refusal), findsOneWidget);
  });

  test('une demande d’achat est reconnue, une question non', () {
    final full = CrowdAssistant.purchaseRequest(
      'Achète le pack Premium de Green Pulse Sensor',
      crowd,
    );
    expect(full?.project?.title, 'Green Pulse Sensor');
    expect(full?.pack?.name, 'Premium');

    final budget = CrowdAssistant.purchaseRequest(
      'Je veux investir 200 € dans AI Ops',
      crowd,
    );
    expect(budget?.project?.title, 'AI Ops Dashboard');
    expect(budget?.budget, 200);
    expect(budget?.pack, isNull);

    expect(CrowdAssistant.purchaseRequest('Je veux acheter', crowd), isNotNull);
    expect(
      CrowdAssistant.purchaseRequest('Comment acheter un pack ?', crowd),
      isNull,
    );
    expect(
      CrowdAssistant.purchaseRequest('Quel pack acheter ?', crowd),
      isNull,
    );
  });

  test('le plus grand pack qui tient dans le budget est choisi', () {
    final project = crowd.projects.last; // jeton à 30 €
    final pack = CrowdAssistant.packForBudget(project, crowd.packs, 200);
    expect(pack, isNotNull);
    expect(pack!.priceFor(project.tokenPrice), lessThanOrEqualTo(200));
    for (final other in crowd.packs) {
      if (other.tokens > pack.tokens) {
        expect(other.priceFor(project.tokenPrice), greaterThan(200));
      }
    }
    expect(CrowdAssistant.packForBudget(project, crowd.packs, 1), isNull);
  });

  test('une demande d’achat n’appelle pas Gemini', () async {
    final calls = <http.Request>[];
    CrowdAssistant.client = fakeGemini('Achat fait !', calls: calls);
    final reply = await CrowdAssistant.answer(
      'Achète le pack Découverte de Green Pulse Sensor',
      crowd,
    );
    expect(reply.purchase, isNotNull);
    expect(calls, isEmpty);
  });

  testWidgets('Crowdy achète un pack après confirmation', (tester) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/funding', arguments: testAdmin));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Assistant Crowdy'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Achète le pack Découverte de Green Pulse Sensor',
    );
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('🛒 Récapitulatif'), findsOneWidget);
    expect(await CrowdTechDatabase.getItems('investments'), isEmpty);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('✅ Achat confirmé'), findsOneWidget);
    final investments = await CrowdTechDatabase.getItems('investments');
    expect(investments, hasLength(1));
    expect(investments.single['projectTitle'], 'Green Pulse Sensor');
    expect(investments.single['pack'], 'Découverte');
    expect(investments.single['ownerKey'], testAdmin.email);

    // Sans projet précisé : Crowdy le fait choisir.
    await tester.enterText(find.byType(TextField), 'Je veux acheter');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Dans quel projet voulez-vous investir ?'),
      findsOneWidget,
    );
  });

  test('quota épuisé (429) : un modèle Lite prend le relais', () async {
    final asked = <String>[];
    CrowdAssistant.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/models')) {
        return http.Response(
          jsonEncode({
            'models': [
              for (final name in [
                'gemini-3.6-flash',
                'gemini-flash-lite-latest',
              ])
                {
                  'name': 'models/$name',
                  'supportedGenerationMethods': ['generateContent'],
                },
            ],
          }),
          200,
        );
      }
      asked.add(path.split('/').last);
      if (path.contains('gemini-3.6-flash')) {
        return http.Response('{"error":{"message":"quota"}}', 429);
      }
      return fakeGeminiResponse(request, 'Réponse du modèle Lite');
    });

    final first = await CrowdAssistant.answer('Quel pack choisir ?', crowd);
    expect(first.text, 'Réponse du modèle Lite');
    expect(first.offline, isFalse);

    // Le modèle au quota épuisé est mis de côté : plus d'attente inutile.
    asked.clear();
    await CrowdAssistant.answer('Quels sont les risques ?', crowd);
    expect(asked, ['gemini-flash-lite-latest:generateContent']);
  });

  test('hors ligne, Crowdy explique pourquoi', () async {
    CrowdAssistant.client = MockClient(
      (request) async => http.Response('{"error":{}}', 429),
    );
    final reply = await CrowdAssistant.answer('Quel pack choisir ?', crowd);
    expect(reply.offline, isTrue);
    expect(reply.offlineReason, contains('Quota gratuit Gemini épuisé'));

    CrowdAssistant.apiKeyOverride = '';
    final noKey = await CrowdAssistant.answer('Quel pack choisir ?', crowd);
    expect(noKey.offlineReason, contains('Clé Gemini absente'));
  });

  test('suivre ou ne plus suivre un projet depuis le chat', () {
    const withIds = CrowdContext(
      projects: [
        FundingProject(
          id: 7,
          title: 'Green Pulse Sensor',
          company: 'EcoByte',
          amountRaised: 0,
          goal: 1000,
          tokenPrice: 30,
          progress: 0,
          feature: 'Capteurs',
        ),
      ],
      packs: TokenPack.defaults,
    );
    final add = CrowdAssistant.followRequest(
      'Ajoute Green Pulse Sensor à mes favoris',
      withIds,
    );
    expect(add?.project.id, 7);
    expect(add?.follow, isTrue);
    final remove = CrowdAssistant.followRequest(
      'Retire EcoByte de mes favoris',
      withIds,
    );
    expect(remove?.follow, isFalse);
    expect(
      CrowdAssistant.followRequest('Quels sont mes favoris ?', withIds),
      isNull,
    );
  });

  test('questions sur le compte : acceptées et réponses hors ligne', () {
    const mine = CrowdContext(
      projects: [],
      packs: TokenPack.defaults,
      investorProfile: 'Prudent',
      limitPerProject: 1000,
      referralCode: 'CT-ABC123',
      referralBonuses: 1,
    );
    for (final question in [
      'Mon code de parrainage',
      'Quels projets je suis en favoris ?',
      'Quel est mon plafond ?',
      'Comment sont débloqués les fonds ?',
    ]) {
      expect(
        CrowdAssistant.isOnTopic(question, mine),
        isTrue,
        reason: question,
      );
    }
    expect(
      CrowdAssistant.offlineAnswer('Mon code de parrainage', mine),
      contains('CT-ABC123'),
    );
    expect(
      CrowdAssistant.offlineAnswer('Quel est mon plafond ?', mine),
      contains('Prudent'),
    );
    expect(
      CrowdAssistant.isOnTopic('Donne-moi un code promo Netflix', mine),
      isFalse,
    );
  });
}
