import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/marketplace/presentation/checkout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  setUp(() async {
    CrowdTechSession.accountKey = null;
    await CrowdTechDatabase.useMemoryForTesting();
  });

  testWidgets('inscription refusée sans les coordonnées obligatoires', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabeled('Nom complet'), 'Lina');
    await tester.enterText(fieldLabeled('Email'), 'lina@example.com');
    await tester.enterText(fieldLabeled('Mot de passe'), 'secret123');
    await tester.enterText(fieldLabeled('Confirmer'), 'secret123');
    final terms = find.byType(CheckboxListTile);
    await tester.ensureVisible(terms);
    await tester.pumpAndSettle();
    await tester.tap(terms);
    await tester.pumpAndSettle();
    await submitRegistration(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    // Adresse, ville, téléphone… manquants : le compte n'est pas créé.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Téléphone requis.'), findsOneWidget);
    expect(find.text('Code postal requis.'), findsOneWidget);
    expect(find.text('Ce champ est requis.'), findsNWidgets(2));
    final accounts = await CrowdTechDatabase.getItems('accounts');
    expect(
      accounts.where((row) => row['email'] == 'lina@example.com'),
      isEmpty,
    );
  });

  test('les coordonnées combinent profil et inscription', () async {
    await AccountService.register(
      name: 'Sami',
      email: 'sami@example.com',
      password: 'secret123',
      role: 'Lecteur',
      details: {'address': '12 rue de la Liberté', 'city': 'Tunis'},
    );
    // Profil existant sans adresse : l'adresse du compte est reprise.
    await CrowdTechDatabase.insertItem('profiles', {
      'accountKey': 'sami@example.com',
      'name': 'Sami B.',
      'email': 'sami@example.com',
      'phone': '+216 20 123 456',
    });
    final contact = await AccountService.contactOf('sami@example.com');
    expect(contact['name'], 'Sami B.');
    expect(contact['phone'], '+216 20 123 456');
    expect(contact['address'], '12 rue de la Liberté');
    expect(contact['city'], 'Tunis');
    expect(contact['postalCode'], '');

    await AccountService.saveContact('sami@example.com', {
      'address': '3 avenue Habib Bourguiba',
      'postalCode': '1001',
    });
    final profiles = await CrowdTechDatabase.getItems('profiles');
    expect(profiles, hasLength(1));
    expect(profiles.single['address'], '3 avenue Habib Bourguiba');
    expect(profiles.single['postalCode'], '1001');
    expect(profiles.single['name'], 'Sami B.');
  });

  testWidgets('la commande est préremplie depuis le compte et modifiable', (
    tester,
  ) async {
    useTallScreen(tester);
    await AccountService.register(
      name: 'Nour',
      email: 'nour@example.com',
      password: 'secret123',
      role: 'Lecteur',
      details: {
        'phone': '+216 22 333 444',
        'address': '5 rue de Marseille',
        'city': 'Sfax',
        'postalCode': '3000',
        'country': 'Tunisie',
      },
    );
    final productId = await CrowdTechDatabase.insertItem('products', {
      'name': 'Casque',
      'price': 50.0,
      'stock': 5,
    });
    await CrowdTechDatabase.insertItem('cart', {
      'productId': productId,
      'quantity': 2,
      'ownerKey': 'nour@example.com',
    });

    await tester.pumpWidget(
      const MaterialApp(home: CheckoutPage(accountKey: 'nour@example.com')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final values = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller!.text)
        .toList();
    expect(values, [
      'Nour',
      'nour@example.com',
      '+216 22 333 444',
      '5 rue de Marseille',
      'Sfax',
      '3000',
    ]);
    expect(find.text('Tunisie'), findsOneWidget);

    // Adresse modifiée pour cette commande uniquement.
    await tester.enterText(find.byType(TextFormField).at(3), '8 rue de Paris');
    await tester.tap(find.text('Valider'));
    await tester.pump();
    await tester.pumpAndSettle();

    final order = (await CrowdTechDatabase.getItems('orders')).single;
    expect(order['address'], '8 rue de Paris, 3000 Sfax, Tunisie');
    expect(order['total'], 100.0);
    // La case « Enregistrer dans mon profil » n'était pas cochée.
    expect(
      (await AccountService.contactOf('nour@example.com'))['address'],
      '5 rue de Marseille',
    );
  });
}
