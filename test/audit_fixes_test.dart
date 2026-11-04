// Corrections de l'audit du projet par rapport au cahier des charges :
// réinitialisation du mot de passe, score de fiabilité, modération, taux de
// change, avis vendeur, réservations et billets.

import 'dart:convert';

import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/funding/domain/currency_service.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';
import 'package:crowdtech/modules/marketplace/domain/seller_reputation.dart';
import 'package:crowdtech/modules/news/domain/article_feedback.dart';
import 'package:crowdtech/modules/news/domain/comment_moderation.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:crowdtech/modules/news/domain/news_search.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void login(String email, [String role = UserRoles.reader]) =>
    CrowdTechSession.start(CrowdUser(name: email, email: email, role: role));

void main() {
  setUp(() async {
    CrowdTechSession.clear();
    await CrowdTechDatabase.useMemoryForTesting();
  });
  tearDown(CrowdTechSession.clear);

  group('Réinitialisation du mot de passe', () {
    Future<void> register() async {
      await AccountService.register(
        name: 'Nour',
        email: 'nour@example.com',
        password: 'secret123',
        role: UserRoles.reader,
        details: {'birthDate': '2000-04-15', 'phone': '+216 20 123 456'},
      );
      CrowdTechSession.clear();
    }

    test('refusée sans preuve d’identité', () async {
      await register();
      await expectLater(
        AccountService.resetPassword(
          email: 'nour@example.com',
          newPassword: 'pirate123',
        ),
        throwsA(isA<AccountException>()),
      );
      await expectLater(
        AccountService.resetPassword(
          email: 'nour@example.com',
          newPassword: 'pirate123',
          birthDate: '01/01/1999',
          phone: '+216 20 123 456',
        ),
        throwsA(isA<AccountException>()),
      );
      final user = await AccountService.login(
        email: 'nour@example.com',
        password: 'secret123',
      );
      expect(user.name, 'Nour');
    });

    test('acceptée avec la date de naissance et le téléphone', () async {
      await register();
      await AccountService.resetPassword(
        email: 'NOUR@example.com',
        newPassword: 'nouveau123',
        birthDate: '15/04/2000',
        phone: '216 20-123-456',
      );
      final user = await AccountService.login(
        email: 'nour@example.com',
        password: 'nouveau123',
      );
      expect(user.email, 'nour@example.com');
    });

    test('jamais pour un administrateur non connecté', () async {
      await AccountService.ensureDefaultAdmin();
      await expectLater(
        AccountService.resetPassword(
          email: AccountService.defaultAdminEmail,
          newPassword: 'pirate123',
          birthDate: '15/04/2000',
          phone: '20123456',
        ),
        throwsA(isA<AccountException>()),
      );
    });

    test(
      'le mot de passe par défaut de l’admin ne peut pas être remis',
      () async {
        await AccountService.ensureDefaultAdmin();
        login(AccountService.defaultAdminEmail, UserRoles.admin);
        await expectLater(
          AccountService.resetPassword(
            email: AccountService.defaultAdminEmail,
            newPassword: AccountService.defaultAdminPassword,
          ),
          throwsA(isA<AccountException>()),
        );
        expect(
          AccountService.isDefaultAdminPassword(
            ' Admin@CrowdTech.app ',
            AccountService.defaultAdminPassword,
          ),
          isTrue,
        );
      },
    );

    test('un administrateur connecté change son mot de passe', () async {
      await AccountService.ensureDefaultAdmin();
      login(AccountService.defaultAdminEmail, UserRoles.admin);
      await AccountService.resetPassword(
        email: AccountService.defaultAdminEmail,
        newPassword: 'NouveauAdmin1',
      );
      CrowdTechSession.clear();
      final user = await AccountService.login(
        email: AccountService.defaultAdminEmail,
        password: 'NouveauAdmin1',
      );
      expect(user.role, UserRoles.admin);
    });
  });

  group('Score de fiabilité', () {
    ArticleReview review(int stars) => ArticleReview(
      articleId: 1,
      ownerKey: 'a',
      authorName: 'A',
      stars: stars,
    );

    test('une seule note ne rend pas une actualité très fiable', () {
      final score = RatingSummary([review(5)]).credibilityFrom(0);
      expect(score, 63);
      expect(TrustLevel.of(score), TrustLevel.medium);
    });

    test('les notes finissent par l’emporter sur le score de départ', () {
      final many = RatingSummary(List.generate(30, (_) => review(5)));
      expect(many.credibilityFrom(50), greaterThan(90));
      final bad = RatingSummary(List.generate(30, (_) => review(1)));
      expect(TrustLevel.of(bad.credibilityFrom(80)), TrustLevel.low);
    });

    test('le score de la source est conservé entre deux notes', () async {
      final id = await CrowdTechDatabase.insertItem('news', {
        'title': 'Article',
        'credibility': 80,
        'ownerKey': 'auteur@x.com',
      });
      login('a@x.com');
      final first = await NewsFeedback.saveReview(
        articleId: id,
        articleTitle: 'Article',
        ownerKey: 'a@x.com',
        stars: 1,
      );
      expect(first, 65); // (80×3 + 20) / 4
      final second = await NewsFeedback.saveReview(
        articleId: id,
        articleTitle: 'Article',
        ownerKey: 'b@x.com',
        stars: 1,
      );
      expect(second, 56); // (80×3 + 20×2) / 5
    });
  });

  group('Modération', () {
    test('mots interdits reconnus sans accent, au pluriel, en majuscules', () {
      for (final text in [
        'Quel debile cet auteur',
        'Ces imbeciles se trompent',
        'Un vrai CRETIN vraiment',
        'De vrais abrutis ici',
      ]) {
        expect(
          CommentModeration.analyze(text).verdict,
          ModerationVerdict.masked,
          reason: text,
        );
      }
    });

    test('pas de masquage à l’intérieur d’un autre mot', () {
      final result = CommentModeration.analyze('Les scampi de Moroni');
      expect(result.verdict, ModerationVerdict.approved);
      expect(result.text, 'Les scampi de Moroni');
    });
  });

  test('recherche sans accents ni cédille', () {
    const item = NewsItem(
      title: 'Marché français',
      source: 'Source',
      summary: 'Résumé',
      tag: 'Tech',
      credibility: 80,
    );
    expect(NewsSearch.search([item], query: 'francais'), [item]);
  });

  test('devise absente de l’API : taux de secours, jamais 1:1', () {
    final rates = ExchangeRates(const {'USD': 1.1}, 'API', DateTime(2026));
    expect(rates.rateOf('USD'), 1.1);
    expect(rates.rateOf('TND'), CurrencyService.fallbackRates['TND']);
    expect(rates.rateOf('EUR'), 1);
  });

  test('avis réservé aux vendeurs de la commande', () async {
    final order = <String, Object?>{
      'ownerKey': 'buyer@x.com',
      'sellerKeys': ['seller@x.com'],
      'status': OrderState.completed,
    };
    final id = await CrowdTechDatabase.insertItem('orders', order);
    login('buyer@x.com');
    await expectLater(
      SellerReputationService.review(
        order: {'id': id, ...order},
        sellerKey: 'autre@x.com',
        stars: 1,
      ),
      throwsA(isA<RuleException>()),
    );
  });

  group('Événements', () {
    test('une seule place par compte', () async {
      final data = <String, Object?>{
        'title': 'Forum',
        'date': '12/03/2099',
        'seats': 5,
      };
      final id = await CrowdTechDatabase.insertItem('events', data);
      final event = {'id': id, ...data};
      login('ada@x.com');
      await EventCapacity.book(
        event: event,
        accountKey: 'ada@x.com',
        name: 'Ada',
        email: 'ada@x.com',
      );
      await expectLater(
        EventCapacity.book(
          event: event,
          accountKey: 'ada@x.com',
          name: 'Ada',
          email: 'ada@x.com',
        ),
        throwsA(isA<RuleException>()),
      );
    });

    test('badge chiffré : contenu illisible et modification détectée', () {
      final badge = AccessBadge.issue(
        ticket: 'CT-SECRET',
        eventId: 7,
        email: 'ada@x.com',
        eventDate: '12/03/2099',
      );
      expect(badge, startsWith('CTB2.'));
      final parts = badge.split('.');
      final raw = base64Url.decode(base64Url.normalize(parts[2]));
      expect(latin1.decode(raw), isNot(contains('CT-SECRET')));
      expect(AccessBadge.decode(badge)!.ticket, 'CT-SECRET');
      // Deux badges identiques n'ont jamais le même chiffré.
      final other = AccessBadge.issue(
        ticket: 'CT-SECRET',
        eventId: 7,
        email: 'ada@x.com',
        eventDate: '12/03/2099',
      );
      expect(other, isNot(badge));
      raw[0] ^= 1;
      final forged =
          '${parts[0]}.${parts[1]}.${base64Url.encode(raw).replaceAll('=', '')}';
      expect(AccessBadge.isAuthentic(forged), isFalse);
      expect(AccessBadge.decode(forged), isNull);
      expect(AccessBadge.isAuthentic('CTB2.abc.def'), isFalse);
      expect(AccessBadge.isAuthentic('CTB2.%%%.%%%'), isFalse);
    });

    test('un ancien badge signé (CTB1) reste accepté', () async {
      const payload = 'CT-OLD|7|abc|1|4070908800';
      final data = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
      final signature = Hmac(
        sha256,
        utf8.encode(AccessBadge.secret),
      ).convert(utf8.encode(payload)).toString().substring(0, 24);
      final badge = 'CTB1.$data.$signature';
      expect(AccessBadge.isAuthentic(badge), isTrue);
      expect(AccessBadge.decode(badge)!.ticket, 'CT-OLD');
      expect(AccessBadge.isAuthentic('CTB1.$data.${'0' * 24}'), isFalse);
    });

    test('un numéro de billet saisi à la main expire', () async {
      await CrowdTechDatabase.insertItem('reservations', {
        'eventId': 7,
        'ticket': 'CT-2',
        'attendeeName': 'Ada',
        'validUntil': DateTime(2099).toIso8601String(),
      });
      final late = await AccessBadge.checkIn('CT-2', now: DateTime(2100));
      expect(late.valid, isFalse);
      expect(late.message, contains('expiré'));
      final onTime = await AccessBadge.checkIn('CT-2', now: DateTime(2098));
      expect(onTime.valid, isTrue);
    });
  });
}
