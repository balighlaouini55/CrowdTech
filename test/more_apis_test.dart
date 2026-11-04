// Nouvelles API gratuites et leurs règles métier : DEV Community et
// Wikipédia (Actus), Frankfurter et Banque mondiale (Crowdfunding), OSRM et
// Zippopotam / Nominatim (Marketplace), Open-Meteo et Nager.Date
// (Événements), Have I Been Pwned, DiceBear et LanguageTool (commun).
// Un faux serveur remplace Internet.

import 'dart:convert';

import 'package:crowdtech/core/auth/password_breach.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/core/network/spell_checker.dart';
import 'package:crowdtech/modules/events/data/events_web_api.dart';
import 'package:crowdtech/modules/events/domain/event_planning.dart';
import 'package:crowdtech/modules/funding/data/funding_web_api.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/modules/marketplace/data/delivery_api.dart';
import 'package:crowdtech/modules/marketplace/domain/delivery_quote.dart';
import 'package:crowdtech/modules/news/data/news_web_api.dart';
import 'package:crowdtech/modules/news/domain/source_check.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:crowdtech/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Faux serveur : une réponse par site.
final fakeServer = MockClient((request) async {
  final url = request.url;
  return switch (url.host) {
    'dev.to' => json([
      {
        'title': 'Securing Flutter apps',
        'description': 'Passkeys et stockage chiffré.',
        'public_reactions_count': 120,
        'comments_count': 8,
        'tag_list': ['flutter', 'security'],
        'url': 'https://dev.to/a/securing',
        'published_timestamp': '2026-10-29T09:34:19Z',
        'user': {'name': 'Ada Dev'},
      },
    ]),
    // Recherche sur les titres : « Paris » n'a aucun rapport avec l'article.
    'fr.wikipedia.org' when url.path.contains('search') => json({
      'pages': [
        {'key': 'Paris', 'title': 'Paris'},
      ],
    }),
    'fr.wikipedia.org' when url.path.endsWith('/RISC-V') => json({
      'type': 'standard',
      'title': 'RISC-V',
      'extract': 'RISC-V est une architecture de jeu d’instructions ouverte.',
      'content_urls': {
        'desktop': {'page': 'https://fr.wikipedia.org/wiki/RISC-V'},
      },
    }),
    'fr.wikipedia.org' when url.path.endsWith('/Mercure') => json({
      'type': 'disambiguation',
      'title': 'Mercure',
      'extract': 'Mercure peut désigner…',
    }),
    'fr.wikipedia.org' => json({}, 404),
    'api.frankfurter.dev' => json({
      'base': 'EUR',
      'rates': {
        '2026-10-05': {'USD': 1.12},
        '2026-10-01': {'USD': 1.10},
      },
    }),
    'api.worldbank.org' => json([
      {'page': 1},
      [
        {
          'country': {'value': 'Tunisia'},
          'date': '2025',
          'value': 5.15,
        },
      ],
    ]),
    'router.project-osrm.org' => json({
      'code': 'Ok',
      'routes': [
        {'distance': 267301.3, 'duration': 11986.4},
      ],
    }),
    'api.zippopotam.us' when url.path == '/fr/75001' => json({
      'places': [
        {'place name': 'Paris 01 Louvre', 'state': 'Île-de-France'},
      ],
    }),
    'api.zippopotam.us' => json({}, 404),
    'nominatim.openstreetmap.org' => json([
      {
        'address': {'county': 'Gremda', 'state': 'Gouvernorat Sfax'},
      },
    ]),
    'api.open-meteo.com' => json({
      'daily': {
        'weather_code': [61],
        'temperature_2m_max': [18.4],
        'temperature_2m_min': [11.2],
        'precipitation_probability_max': [80],
      },
    }),
    'date.nager.at' => json([
      {'date': '2027-03-20', 'name': 'Independence Day', 'localName': 'عيد'},
    ]),
    'api.pwnedpasswords.com' => http.Response(
      // Suffixe SHA-1 de « password » (préfixe 5BAA6).
      '1E4C9B93F3F0682250B6CF8331B7EE68FD8:9659365\r\n'
      '0018A45C4D1DEF81644B54AB7F969B88D65:3\r\n',
      200,
    ),
    'api.languagetool.org' => json({
      'matches': [
        {
          'offset': 8,
          'length': 4,
          'message': 'Faute de frappe possible trouvée.',
          'replacements': [
            {'value': 'très'},
            {'value': 'près'},
          ],
        },
        {
          'offset': 13,
          'length': 7,
          'message': 'Faute de frappe possible trouvée.',
          'replacements': [
            {'value': 'content'},
          ],
        },
      ],
    }),
    _ => http.Response('inconnu', 404),
  };
});

void main() {
  setUp(() => CrowdTechApi.client = fakeServer);
  tearDown(() => CrowdTechApi.client = http.Client());

  group('Actus : DEV Community et Wikipédia', () {
    test('fiabilité de départ et catégorie d’un article DEV', () {
      expect(SourceCheck.devToCredibility(reactions: 0, comments: 0), 55);
      expect(SourceCheck.devToCredibility(reactions: 120, comments: 8), 69);
      expect(SourceCheck.devToCredibility(reactions: 9000, comments: 0), 92);
      expect(SourceCheck.tagOf(['javascript', 'security']), 'Sécurité');
      expect(SourceCheck.tagOf(['rust']), 'Web');
    });

    test('import DEV au format des actualités', () async {
      final articles = await NewsWebApi.fetchDevTo();
      final article = articles.single;
      expect(article['source'], 'DEV Community');
      expect(article['tag'], 'Mobile');
      expect(article['credibility'], 69);
      expect(article['author'], 'Ada Dev');
      expect(article['publishedAt'], '2026-10-29');
    });

    test('sujet Wikipédia : mots porteurs de sens du titre', () {
      expect(
        SourceCheck.topicOf(
          'Les centres de données passent au refroidissement liquide',
        ),
        'centres données passent refroidissement',
      );
    });

    test('pages Wikipédia à essayer pour un titre', () {
      expect(
        SourceCheck.wikiCandidates(
          'Des puces RISC-V dans les ordinateurs portables',
          tag: 'Matériel',
        ),
        ['RISC-V', 'Matériel informatique'],
      );
      expect(
        SourceCheck.wikiCandidates(
          'Les startups deep tech et le cloud',
          tag: 'Startups',
        ),
        ['Start-up', 'Entreprise de technologie profonde', 'Cloud computing'],
      );
      expect(
        SourceCheck.isRelevant('Paris', 'Tunisie fonds startups'),
        isFalse,
      );
      expect(SourceCheck.isRelevant('Start-up', 'startups tunisie'), isTrue);
    });

    test('vérification Wikipédia : page trouvée, homonymie, ou rien', () async {
      final summary = await NewsWebApi.factCheck(
        'Des puces RISC-V dans les portables',
        tag: 'Matériel',
      );
      expect(summary!.title, 'RISC-V');
      expect(summary.extract, contains('architecture'));
      expect(summary.url, endsWith('/RISC-V'));
      // Page d'homonymie ignorée ; recherche hors sujet (« Paris ») refusée.
      expect(await NewsWebApi.pageSummary('Mercure'), isNull);
      expect(await NewsWebApi.wikipediaSummary('fonds amorçage'), isNull);
      expect(await NewsWebApi.factCheck('Un sujet inventé'), isNull);
    });
  });

  group('Crowdfunding : Frankfurter et Banque mondiale', () {
    test('historique trié par date et variation', () async {
      final history = await FundingWebApi.rateHistory(
        'USD',
        today: DateTime(2026, 10, 5),
      );
      expect([for (final point in history) point.rate], [1.10, 1.12]);
      expect(
        PortfolioAnalytics.variationPercent([1.10, 1.12]),
        closeTo(1.818, 0.001),
      );
      final chart = PortfolioAnalytics.tokenPriceChart(
        tokenPrice: 50,
        currency: 'USD',
        history: history,
      );
      final data = ((chart['data']! as Map)['datasets']! as List).first as Map;
      expect(data['data'], [55.0, 56.0]);
    });

    test('inflation et rendement réel (Fisher)', () async {
      final inflation = await FundingWebApi.inflation('TN');
      expect(inflation!.percent, 5.15);
      expect(inflation.year, 2025);
      // 8 % nominal avec 5 % d'inflation → 2,86 % réel (et non 3 %).
      expect(PortfolioAnalytics.realRatePercent(8, 5), closeTo(2.857, 0.001));
      expect(
        PortfolioAnalytics.realValue(1000, 8, 5, 1),
        closeTo(1028.57, 0.01),
      );
      expect(PortfolioAnalytics.countryOfCity('Sfax'), 'TN');
      expect(PortfolioAnalytics.countryOfCity('Paris'), 'FR');
    });
  });

  group('Marketplace : OSRM et codes postaux', () {
    test('frais et délai selon la distance', () {
      final near = DeliveryQuote.fromRoute(km: 10, hours: 0.3);
      expect(near.cost, 4.2);
      expect(near.days, 2);
      final far = DeliveryQuote.fromRoute(km: 2000, hours: 22);
      expect(far.cost, DeliveryQuote.maxCost);
      expect(far.days, 1 + 6);
      final free = DeliveryQuote.fromRoute(km: 300, hours: 4, orderTotal: 899);
      expect(free.isFree, isTrue);
    });

    test('itinéraire OSRM entre deux villes', () async {
      final route = await DeliveryApi.route(
        (lat: 36.8, lon: 10.18),
        (lat: 34.74, lon: 10.76),
      );
      expect(route!.km, closeTo(267.3, 0.1));
      expect(route.hours, closeTo(3.33, 0.01));
    });

    test('code postal : Zippopotam (France), Nominatim (Tunisie)', () async {
      final paris = await DeliveryApi.placesForPostalCode('FR', '75001');
      expect(PostalCheck.matches('Paris', paris), isTrue);
      expect(PostalCheck.matches('Lyon', paris), isFalse);
      expect(await DeliveryApi.placesForPostalCode('FR', '00000'), isEmpty);

      final sfax = await DeliveryApi.placesForPostalCode('TN', '3000');
      expect(PostalCheck.matches('Sfax', sfax), isTrue);
      expect(PostalCheck.matches('Tunis', sfax), isFalse);
      expect(PostalCheck.normalize('Gabès-Sud'), 'gabes sud');
    });
  });

  group('Événements : Open-Meteo et Nager.Date', () {
    test('période des prévisions et codes météo', () {
      final now = DateTime(2026, 11, 2);
      expect(
        EventPlanning.hasForecast(DateTime(2026, 11, 10), now: now),
        isTrue,
      );
      expect(
        EventPlanning.hasForecast(DateTime(2027, 1, 10), now: now),
        isFalse,
      );
      expect(EventPlanning.hasForecast(DateTime(2026, 10), now: now), isFalse);
      expect(
        EventPlanning.daysUntilForecast(DateTime(2026, 11, 30), now: now),
        13,
      );
      expect(EventPlanning.weatherOf(0).label, 'Ensoleillé');
      expect(EventPlanning.weatherOf(95).emoji, '⛈️');
    });

    test('météo prévue et conseil', () async {
      final day = DateTime.now().add(const Duration(days: 3));
      final forecast = await EventsWebApi.forecast(36.8, 10.18, day);
      expect(forecast!.label, 'Pluie');
      expect(forecast.summary, contains('11–18 °C'));
      expect(forecast.advice, contains('parapluie'));
      // Trop loin : pas d'appel, pas de prévision.
      expect(await EventsWebApi.forecast(36.8, 10.18, DateTime(2030)), isNull);
    });

    test('jour férié détecté', () async {
      final holidays = await EventsWebApi.holidays(2027, 'TN');
      expect(
        EventPlanning.holidayOn(DateTime(2027, 3, 20, 14), holidays)?.name,
        'Independence Day',
      );
      expect(EventPlanning.holidayOn(DateTime(2027, 3, 21), holidays), isNull);
    });
  });

  group('Commun : mots de passe, avatars, correcteur', () {
    test('mot de passe divulgué : seul le préfixe est envoyé', () async {
      final parts = PasswordBreach.hashParts('password');
      expect(parts.prefix, '5BAA6');
      expect(await PasswordBreach.breachCount('password'), 9659365);
      expect(await PasswordBreach.check('password'), contains('fuite'));
      expect(await PasswordBreach.check('Un-mot-de-passe-unique-42'), isNull);
    });

    test('service indisponible : personne n’est bloqué', () async {
      CrowdTechApi.client = MockClient((_) async => http.Response('', 503));
      expect(await PasswordBreach.check('password'), isNull);
    });

    test('avatar DiceBear sans envoyer l’email', () {
      final url = UserAvatar.urlFor('Ada@Example.com');
      expect(url, startsWith('https://api.dicebear.com/9.x/thumbs/png'));
      expect(url, isNot(contains('example')));
      expect(url, UserAvatar.urlFor('ada@example.com'));
      expect(UserAvatar.initialsOf('Sarah Ben Ali'), 'SB');
    });

    test('fautes trouvées puis appliquées selon le choix', () async {
      const text = 'Je suis tres contant.';
      final issues = await SpellChecker.check(text);
      expect([for (final issue in issues) issue.original], ['tres', 'contant']);
      // Corriger le 1er mot, garder le 2e.
      expect(
        SpellChecker.apply(text, issues, {issues[0]: 'très', issues[1]: null}),
        'Je suis très contant.',
      );
      expect(
        SpellChecker.apply(text, issues, {
          issues[0]: 'très',
          issues[1]: 'content',
        }),
        'Je suis très content.',
      );
      expect(SpellChecker.apply(text, issues, {}), text);
    });

    testWidgets('fenêtre du correcteur : corriger ou garder', (tester) async {
      const text = 'Je suis tres contant.';
      final issues = SpellChecker.parse(text, [
        {
          'offset': 8,
          'length': 4,
          'message': 'Faute',
          'replacements': [
            {'value': 'très'},
          ],
        },
        {
          'offset': 13,
          'length': 7,
          'message': 'Faute',
          'replacements': [
            {'value': 'content'},
          ],
        },
      ]);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SpellCheckSheet(text: text, issues: issues),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('2 faute(s) possible(s)'), findsOneWidget);
      // Par défaut tout est corrigé ; on garde « contant ».
      await tester.tap(find.text('Garder « contant »'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer (1)'));
      await tester.pumpAndSettle();
      expect(result, 'Je suis très contant.');
    });
  });
}
