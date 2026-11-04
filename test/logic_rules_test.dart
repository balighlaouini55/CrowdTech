// Règles de cohérence : stock au paiement, suppressions, contenus personnels,
// simulateur composé.

import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/presentation/roi_simulator_page.dart';
import 'package:crowdtech/modules/news/domain/news_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(CrowdTechDatabase.useMemoryForTesting);

  test('une commande est refusée si le stock a baissé entre-temps', () async {
    final id = await CrowdTechDatabase.insertItem('products', {
      'name': 'Casque',
      'price': 100.0,
      'category': 'Audio',
      'stock': 2,
    });
    await CrowdTechDatabase.insertItem('cart', {
      'productId': id,
      'quantity': 2,
      'ownerKey': 'b@example.com',
    });
    // Un premier client achète 1 exemplaire.
    await CrowdTechDatabase.createOrderAndClearCart({
      'ownerKey': 'a@example.com',
      'items': [
        {'productId': id, 'quantity': 1},
      ],
    });
    // Le second en veut encore 2 : il n'en reste qu'un.
    await expectLater(
      CrowdTechDatabase.createOrderAndClearCart({
        'ownerKey': 'b@example.com',
        'items': [
          {'productId': id, 'quantity': 2},
        ],
      }),
      throwsA(
        isA<RuleException>().having(
          (error) => error.message,
          'message',
          contains('1 disponible(s), 2 demandé(s)'),
        ),
      ),
    );
    // Rien n'a été écrit : stock, commandes et panier inchangés.
    expect((await CrowdTechDatabase.getItems('products')).single['stock'], 1);
    expect(await CrowdTechDatabase.getItems('orders'), hasLength(1));
    expect(await CrowdTechDatabase.getItems('cart'), hasLength(1));
  });

  test(
    'un projet financé ou un événement réservé ne peut être supprimé',
    () async {
      final project = await CrowdTechDatabase.insertItem('funding', {
        'title': 'Projet',
      });
      await CrowdTechDatabase.insertItem('investments', {'projectId': project});
      final event = await CrowdTechDatabase.insertItem('events', {
        'title': 'Forum',
      });
      await CrowdTechDatabase.insertItem('reservations', {'eventId': event});

      await expectLater(
        CrowdTechDatabase.deleteItem('funding', project),
        throwsA(isA<RuleException>()),
      );
      await expectLater(
        CrowdTechDatabase.deleteItem('events', event),
        throwsA(isA<RuleException>()),
      );
      expect(await CrowdTechDatabase.getItems('funding'), hasLength(1));
      expect(await CrowdTechDatabase.getItems('events'), hasLength(1));
    },
  );

  test(
    'supprimer une actualité ou un produit nettoie ce qui en dépend',
    () async {
      final article = await CrowdTechDatabase.insertItem('news', {
        'title': 'A',
      });
      final other = await CrowdTechDatabase.insertItem('news', {'title': 'B'});
      await CrowdTechDatabase.insertItem('news_comments', {
        'articleId': article,
        'text': 'Commentaire de A',
      });
      await CrowdTechDatabase.insertItem('news_comments', {
        'articleId': other,
        'text': 'Commentaire de B',
      });
      await CrowdTechDatabase.insertItem('news_votes', {
        'articleId': article,
        'stars': 4,
      });
      final product = await CrowdTechDatabase.insertItem('products', {
        'name': 'Montre',
      });
      await CrowdTechDatabase.insertItem('cart', {
        'productId': product,
        'quantity': 1,
      });

      await CrowdTechDatabase.deleteItem('news', article);
      await CrowdTechDatabase.deleteItem('products', product);

      final comments = await CrowdTechDatabase.getItems('news_comments');
      expect(comments.single['text'], 'Commentaire de B');
      expect(await CrowdTechDatabase.getItems('news_votes'), isEmpty);
      expect(await CrowdTechDatabase.getItems('cart'), isEmpty);
    },
  );

  test('l’auteur ne peut pas noter sa propre actualité', () async {
    final id = await CrowdTechDatabase.insertItem('news', {
      'title': 'Mon article',
      'credibility': 0,
      'ownerKey': 'auteur@example.com',
    });
    await expectLater(
      NewsFeedback.saveReview(
        articleId: id,
        articleTitle: 'Mon article',
        ownerKey: 'auteur@example.com',
        stars: 5,
      ),
      throwsA(isA<RuleException>()),
    );
    expect(await CrowdTechDatabase.getItems('news_votes'), isEmpty);
  });

  test('le simulateur calcule des intérêts composés, gains ou pertes', () {
    expect(compoundValue(1000, 5, 1), closeTo(1050, 0.001));
    expect(compoundValue(1000, 5, 3), closeTo(1157.625, 0.001));
    expect(compoundValue(1000, -20, 2), closeTo(640, 0.001));
  });
}
