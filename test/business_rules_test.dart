import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/marketplace/presentation/marketplace_screen.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  setUp(CrowdTechDatabase.useMemoryForTesting);

  test('une commande diminue le stock des produits commandés', () async {
    final id = await CrowdTechDatabase.insertItem('products', {
      'name': 'Casque',
      'price': 100.0,
      'category': 'Accessoire',
      'stock': 5,
    });
    await CrowdTechDatabase.createOrderAndClearCart({
      'items': [
        {'productId': id, 'productName': 'Casque', 'quantity': 2},
      ],
      'total': 200.0,
    });
    expect((await CrowdTechDatabase.getItems('products')).single['stock'], 3);
  });

  test('un projet dont la date limite est passée est clôturé', () {
    FundingProject project(String? deadline) => FundingProject(
      title: 'P',
      company: 'C',
      amountRaised: 0,
      goal: 100,
      tokenPrice: 10,
      progress: 0,
      feature: 'F',
      deadline: deadline,
    );
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final inTenDays = DateTime.now().add(const Duration(days: 10));
    expect(project(isoDate(yesterday)).isClosed, isTrue);
    expect(project(isoDate(inTenDays)).isClosed, isFalse);
    expect(project(isoDate(inTenDays)).daysLeft, 10);
    expect(project(null).isClosed, isFalse);
  });

  test('formats de date et de montant', () {
    expect(parseFlexibleDate('31/02/2026'), isNull);
    expect(parseFlexibleDate('05/03/2026'), DateTime(2026, 3, 5));
    expect(formatDate('2026-12-31'), '31/12/2026');
    expect(formatDate('12 Nov 2026'), '12 Nov 2026');
    expect(formatMoney(1499), '1 499 €');
    expect(formatMoney(12.5), '12,50 €');
    expect(optionalUrl('ftp://x'), isNotNull);
    expect(optionalUrl('https://example.com/a'), isNull);
  });

  testWidgets('un produit en rupture ne peut pas être ajouté au panier', (
    tester,
  ) async {
    useTallScreen(tester);
    await CrowdTechDatabase.loadSeededItems('products', const [
      {
        'name': 'Produit épuisé',
        'price': 10.0,
        'rating': null,
        'category': 'Accessoire',
        'stock': 0,
      },
    ]);
    await tester.pumpWidget(const MaterialApp(home: MarketplaceScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Rupture'), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.add_shopping_cart_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
