import 'dart:async';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

Future<void> pumpDatabaseAndSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> prepareDemoDatabase() async {
  await AccountService.register(
    name: 'Testeur',
    email: 'test@example.com',
    password: 'secret123',
    role: 'Investisseur',
    details: const {'birthDate': '2000-04-15', 'phone': '+216 20 123 456'},
  );
  await AccountService.logout();
  await CrowdTechDatabase.loadSeededItems('news', const [
    {
      'title': 'L’IA générative transforme le développement',
      'source': 'Tech Daily',
      'credibility': 96,
      'tag': 'IA',
      'summary': 'Les assistants de code accélèrent les tâches répétitives.',
    },
    {
      'title': 'Les startups renforcent leur sécurité par passkeys',
      'source': 'Cyber Weekly',
      'credibility': 92,
      'tag': 'Sécurité',
      'summary': 'Les entreprises migrent vers des mécanismes plus sûrs.',
    },
    {
      'title': 'Le cloud hybride gagne du terrain',
      'source': 'Cloud Lab',
      'credibility': 90,
      'tag': 'Cloud',
      'summary': 'Les PME cherchent un équilibre coût-flexibilité.',
    },
  ]);
  await CrowdTechDatabase.loadSeededItems('funding', const [
    {
      'title': 'AI Ops Dashboard',
      'company': 'NovaStack',
      'amountRaised': 42000.0,
      'goal': 80000.0,
      'tokenPrice': 45.0,
      'progress': 52,
      'feature': 'Supprimer les tâches répétitives',
    },
    {
      'title': 'Green Pulse Sensor',
      'company': 'EcoByte',
      'amountRaised': 65000.0,
      'goal': 95000.0,
      'tokenPrice': 30.0,
      'progress': 68,
      'feature': 'Analyse des données environnementales',
    },
  ]);
  await CrowdTechDatabase.loadSeededItems('products', const [
    {
      'name': 'Laptop Edge Pro',
      'price': 1499.0,
      'rating': 4.8,
      'category': 'Portable',
    },
    {
      'name': 'Drone Insight X',
      'price': 899.0,
      'rating': 4.7,
      'category': 'Drone',
    },
    {
      'name': 'Monitor Ultra 4K',
      'price': 699.0,
      'rating': 4.9,
      'category': 'Écran',
    },
  ]);
  await CrowdTechDatabase.loadSeededItems('events', const [
    {
      'title': 'Tech Innovation Summit',
      'date': '12 Nov 2026',
      'city': 'Paris',
      'seats': 80,
    },
    {
      'title': 'Startup & AI Forum',
      'date': '18 Nov 2026',
      'city': 'Lyon',
      'seats': 36,
    },
  ]);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await CrowdTechDatabase.resetForTesting();
  });

  test(
    'SQLite supports create, read, update, delete and seeded samples',
    () async {
      await CrowdTechDatabase.resetForTesting();
      final seeded = await CrowdTechDatabase.loadSeededItems('news', [
        {'title': 'Article exemple'},
      ]);
      expect(seeded, hasLength(1));
      expect(seeded.single['title'], 'Article exemple');

      final id = await CrowdTechDatabase.insertItem('news', {
        'title': 'Article ajouté',
      });
      expect(await CrowdTechDatabase.getItems('news'), hasLength(2));

      final updated = await CrowdTechDatabase.updateItem('news', id, {
        'title': 'Article modifié',
      });
      expect(updated, 1);
      expect(
        (await CrowdTechDatabase.getItems('news'))
            .singleWhere((item) => item['id'] == id)['title'],
        'Article modifié',
      );

      final deleted = await CrowdTechDatabase.deleteItem('news', id);
      expect(deleted, 1);
      expect(await CrowdTechDatabase.getItems('news'), hasLength(1));
    },
  );

  test(
    'SQLite records persist after closing and reopening the database',
    () async {
      await CrowdTechDatabase.resetForTesting();
      await CrowdTechDatabase.loadSeededItems('products', const []);
      await CrowdTechDatabase.insertItem('products', {
        'name': 'Produit conservé',
        'price': 12.5,
      });
      await CrowdTechDatabase.close();

      final records = await CrowdTechDatabase.getItems('products');
      expect(records, hasLength(1));
      expect(records.single['name'], 'Produit conservé');
      await CrowdTechDatabase.resetForTesting();
    },
  );

  test('email and password validators reject invalid values', () {
    expect(validateEmail(null), 'Email requis.');
    expect(validateEmail('pas-une-adresse'), 'Email invalide.');
    expect(validateEmail('user@example.com'), isNull);
    expect(validatePassword('court1'), 'Minimum 8 caractères.');
    expect(
      validatePassword('abcdefgh'),
      'Ajoutez au moins une lettre et un chiffre.',
    );
    expect(validatePassword('CrowdTech123'), isNull);
  });

  testWidgets('login validates input and opens the CrowdTech dashboard', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());

    expect(find.text('CrowdTech'), findsOneWidget);
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();
    expect(find.text('Email requis.'), findsOneWidget);

    await tester.ensureVisible(find.text('Mot de passe oublié ?'));
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    final resetFields = find.byType(TextFormField);
    await tester.enterText(resetFields.at(0), 'test@example.com');
    // Sans preuve d'identité, le mot de passe n'est pas changé.
    await tester.enterText(resetFields.at(1), '01/01/1990');
    await tester.enterText(resetFields.at(2), '00000000');
    await tester.enterText(resetFields.at(3), 'nouveau123');
    await tester.enterText(resetFields.at(4), 'nouveau123');
    await tester.ensureVisible(find.text('Changer le mot de passe'));
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ne correspondent pas'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(resetFields.at(1), '15/04/2000');
    await tester.enterText(resetFields.at(2), '+216 20 123 456');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mot de passe modifié'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // L’ancien mot de passe est refusé, le nouveau fonctionne.
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton).first);
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'nouveau123');
    await tester.tap(find.byType(ElevatedButton).first);
    await pumpDatabaseAndSettle(tester);

    // Après la connexion : tableau de bord, puis onglet Actus.
    expect(find.text('PORTEFEUILLE INVESTI'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(navTab('Actus'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Veille stratégique vérifiée'), findsOneWidget);
    expect(find.text('Actualités tech'), findsOneWidget);
  });

  testWidgets('the app navigates between business modules', (tester) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton).first);
    await pumpDatabaseAndSettle(tester);
    await tester.tap(navTab('Crowd'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Projets à financer'), findsOneWidget);

    await tester.tap(navTab('Store'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Laptop Edge Pro'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Drone');
    await tester.pumpAndSettle();
    expect(find.text('Drone Insight X'), findsOneWidget);
    expect(find.text('Laptop Edge Pro'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(navTab('Agenda'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Tech Innovation Summit'), findsOneWidget);

    await tester.tap(navTab('Profil'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Testeur'), findsOneWidget);
    expect(find.text('Investisseur'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('business modules can open through named routes', (tester) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/events', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);

    expect(find.text('Salons & conférences'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('module subpages support CRUD and dedicated workflows', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await CrowdTechDatabase.insertItem('news', {
      'title': 'Article personnel',
      'source': 'Source locale',
      'credibility': 0,
      'tag': 'Test',
      'summary': 'Un article créé pour vérifier la page de gestion.',
      'ownerKey': 'demo@crowdtech.app',
    });
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    unawaited(navigator.pushNamed('/news', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Autres pages actualités'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gérer tous les articles'));
    await tester.pumpAndSettle();
    expect(find.text('Article personnel'), findsOneWidget);
    expect(
      find.text('L’IA générative transforme le développement'),
      findsOneWidget,
    );
    final articleTile = find.ancestor(
      of: find.text('Article personnel'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: articleTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Article modifié');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      (await CrowdTechDatabase.getItems('news'))
          .any((item) => item['title'] == 'Article modifié'),
      isTrue,
    );

    final editedArticleTile = find.ancestor(
      of: find.text('Article modifié'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: editedArticleTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(
      (await CrowdTechDatabase.getItems('news'))
          .any((item) => item['title'] == 'Article modifié'),
      isFalse,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(navTab('Crowd'));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Autres pages crowdfunding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulateur de rendement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '1000');
    // Le choix du pays (inflation) pousse le bouton plus bas.
    await tester.ensureVisible(find.text('Calculer la simulation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculer la simulation'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 050 €'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 050 €'), findsOneWidget);
    expect(find.text('+50 € de gain'), findsOneWidget);
  });

  testWidgets('each module can edit and delete its own content', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    Future<void> verifyManagement({
      required String route,
      required String menuTooltip,
      required String menuItem,
      required String collection,
      required String sampleTitle,
      required String updatedTitle,
    }) async {
      unawaited(navigator.pushNamed(route, arguments: testAdmin));
      await pumpDatabaseAndSettle(tester);
      await tester.tap(find.byTooltip(menuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(menuItem));
      await tester.pumpAndSettle();

      expect(find.text(sampleTitle), findsOneWidget);
      final recordTile = find.ancestor(
        of: find.text(sampleTitle),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: recordTile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, updatedTitle);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        (await CrowdTechDatabase.getItems(collection))
            .any((item) => item.values.contains(updatedTitle)),
        isTrue,
      );

      final updatedTile = find.ancestor(
        of: find.text(updatedTitle),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: updatedTile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      expect(
        (await CrowdTechDatabase.getItems(collection))
            .any((item) => item.values.contains(updatedTitle)),
        isFalse,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await verifyManagement(
      route: '/news',
      menuTooltip: 'Autres pages actualités',
      menuItem: 'Gérer tous les articles',
      collection: 'news',
      sampleTitle: 'Le cloud hybride gagne du terrain',
      updatedTitle: 'Article actualités modifié',
    );
    await verifyManagement(
      route: '/funding',
      menuTooltip: 'Autres pages crowdfunding',
      menuItem: 'Gérer tous les projets',
      collection: 'funding',
      sampleTitle: 'Green Pulse Sensor',
      updatedTitle: 'Projet crowdfunding modifié',
    );
    await verifyManagement(
      route: '/marketplace',
      menuTooltip: 'Autres pages marketplace',
      menuItem: 'Gérer tous les produits',
      collection: 'products',
      sampleTitle: 'Monitor Ultra 4K',
      updatedTitle: 'Produit marketplace modifié',
    );
    await verifyManagement(
      route: '/events',
      menuTooltip: 'Autres pages événements',
      menuItem: 'Gérer tous les événements',
      collection: 'events',
      sampleTitle: 'Startup & AI Forum',
      updatedTitle: 'Événement CrowdTech modifié',
    );
  });

  testWidgets('event tickets expose a badge and local check-in page', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await CrowdTechDatabase.insertItem('reservations', {
      'eventId': 1,
      'eventTitle': 'Tech Innovation Summit',
      'attendeeName': 'Ada Lovelace',
      'email': 'admin@crowdtech.app',
      'ownerKey': 'admin@crowdtech.app',
      'ticket': 'CT-TEST-2026',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    unawaited(navigator.pushNamed('/events', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Autres pages événements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes billets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tech Innovation Summit'));
    await tester.pumpAndSettle();
    expect(find.text('CT-TEST-2026'), findsOneWidget);
    expect(find.textContaining('Billet de démonstration'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Autres pages événements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contrôle des entrées'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'CT-TEST-2026');
    await tester.tap(find.text('Vérifier le billet'));
    await tester.pumpAndSettle();
    expect(find.text('Entrée validée : Ada Lovelace.'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('reservations')).single['checkedIn'],
      isTrue,
    );
  });

  testWidgets('each business module can add validated demo content', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    unawaited(navigator.pushNamed('/news', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Actualités tech'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajouter une actualité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Ce champ est requis.'), findsWidgets);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Nouvelle actualité CrowdTech',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Source démo');
    await tester.enterText(find.byType(TextFormField).at(2), 'Innovation');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'Un résumé assez long pour valider le nouvel article.',
    );
    await tester.tap(find.text('Enregistrer'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Nouvelle actualité CrowdTech'), findsOneWidget);
    expect(find.text('À vérifier'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('news'))
          .any((item) => item['title'] == 'Nouvelle actualité CrowdTech'),
      isTrue,
    );

    unawaited(navigator.pushNamed('/funding', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un projet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Projet de test');
    await tester.enterText(find.byType(TextFormField).at(1), 'Équipe démo');
    await tester.enterText(find.byType(TextFormField).at(2), '10000');
    await tester.enterText(find.byType(TextFormField).at(3), '25');
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Créer une fonctionnalité',
    );
    await tester.tap(find.text('Enregistrer'));
    await pumpDatabaseAndSettle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Projet de test'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('funding'))
          .any((item) => item['title'] == 'Projet de test'),
      isTrue,
    );

    unawaited(navigator.pushNamed('/marketplace', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un produit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Clavier démo');
    await tester.enterText(find.byType(TextFormField).at(1), 'Accessoire');
    await tester.enterText(find.byType(TextFormField).at(2), '49.99');
    await tester.tap(find.text('Enregistrer'));
    await pumpDatabaseAndSettle(tester);
    expect(find.text('Clavier démo'), findsOneWidget);
    expect(find.text('Nouveau · aucun avis'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('products'))
          .any((item) => item['name'] == 'Clavier démo'),
      isTrue,
    );
    unawaited(navigator.pushNamed('/events', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Conférence démo');
    await tester.enterText(find.byType(TextFormField).at(1), '25 déc. 2026');
    await tester.enterText(find.byType(TextFormField).at(2), 'Paris');
    await tester.enterText(find.byType(TextFormField).at(3), '30');
    await tester.tap(find.text('Enregistrer'));
    await pumpDatabaseAndSettle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Conférence démo'), findsOneWidget);
    expect(find.text('30 places restantes'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('events'))
          .any((item) => item['title'] == 'Conférence démo'),
      isTrue,
    );
  });

  testWidgets('content creation forms reject invalid values', (tester) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    unawaited(navigator.pushNamed('/news', arguments: testAdmin));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter une actualité'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Titre');
    await tester.enterText(find.byType(TextFormField).at(1), 'Source');
    await tester.enterText(find.byType(TextFormField).at(2), 'Tech');
    await tester.enterText(find.byType(TextFormField).at(3), 'Court');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Saisissez au moins 10 caractères.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(navTab('Crowd'));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un projet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Projet invalide');
    await tester.enterText(find.byType(TextFormField).at(1), 'Équipe');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.enterText(find.byType(TextFormField).at(3), '-5');
    await tester.enterText(find.byType(TextFormField).at(4), 'Fonctionnalité');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(
      find.text('Saisissez un nombre supérieur ou égal à 0.01.'),
      findsNWidgets(2),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(navTab('Store'));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un produit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Produit invalide',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Accessoire');
    await tester.enterText(find.byType(TextFormField).at(2), '-1');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(
      find.text('Saisissez un nombre supérieur ou égal à 0.01.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(navTab('Agenda'));
    await pumpDatabaseAndSettle(tester);
    await tester.tap(find.byTooltip('Ajouter un événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Événement test');
    await tester.enterText(find.byType(TextFormField).at(1), '25 déc. 2026');
    await tester.enterText(find.byType(TextFormField).at(2), 'Paris');
    await tester.enterText(find.byType(TextFormField).at(3), '0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(
      find.text('Saisissez un nombre supérieur ou égal à 1.'),
      findsOneWidget,
    );
  });

  testWidgets('investment, cart checkout, and event booking respond to input', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton).first);
    await pumpDatabaseAndSettle(tester);
    final testProfile = (await CrowdTechDatabase.getItems('profiles'))
        .firstWhere((profile) => profile['accountKey'] == 'test@example.com');
    await CrowdTechDatabase.updateItem(
      'profiles',
      testProfile['id']! as int,
      {
        ...testProfile,
        'name': 'Testeur Profile',
        'email': 'profil@example.com',
        'phone': '+216 20 123 456',
        'address': '10 avenue du Test',
        'postalCode': '1000',
        'city': 'Tunis',
        'country': 'Tunisie',
      }..remove('id'),
    );

    await tester.tap(navTab('Crowd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pack Supporter'));
    await tester.pump();
    await tester.tap(find.textContaining('Acheter le pack Supporter'));
    await tester.pumpAndSettle();
    expect(find.text('42 900 € levés'), findsOneWidget);
    expect(
      (await CrowdTechDatabase.getItems('funding')).firstWhere(
        (item) => item['title'] == 'AI Ops Dashboard',
      )['amountRaised'],
      42900.0,
    );
    final investments = await CrowdTechDatabase.getItems('investments');
    expect(investments, hasLength(1));
    expect(investments.single['pack'], 'Supporter');
    expect(investments.single['tokens'], 21);
    expect(investments.single['amount'], 900.0);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Store'));
    await tester.pumpAndSettle();
    final addToCart = find.byIcon(Icons.add_shopping_cart_rounded).first;
    await tester.ensureVisible(addToCart);
    await tester.pumpAndSettle();
    await tester.ensureVisible(addToCart);
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await tester.pump();
    expect(find.text('Laptop Edge Pro ajouté au panier.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Votre panier (1)'), findsOneWidget);
    expect(find.textContaining('1 499'), findsWidgets);
    await tester.tap(find.text('Confirmer la commande'));
    await tester.pumpAndSettle();
    final checkoutFields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller!.text)
        .toList();
    expect(checkoutFields, [
      'Testeur Profile',
      'profil@example.com',
      '+216 20 123 456',
      '10 avenue du Test',
      'Tunis',
      '1000',
    ]);
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Valider'));
    await tester.pump();
    expect(find.text('Saisissez votre nom.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), '1 rue des Tests');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Badge>(
            find.descendant(
              of: find.byTooltip('Ouvrir le panier'),
              matching: find.byType(Badge),
            ),
          )
          .isLabelVisible,
      isFalse,
    );
    expect(await CrowdTechDatabase.getItems('cart'), isEmpty);
    final orders = await CrowdTechDatabase.getItems('orders');
    expect(orders, hasLength(1));
    expect(orders.single['customerName'], 'Ada Lovelace');
    expect(orders.single['email'], 'ada@example.com');
    expect(orders.single['phone'], '+216 20 123 456');
    expect(orders.single['address'], '1 rue des Tests, 1000 Tunis, Tunisie');
    expect(orders.single['street'], '1 rue des Tests');
    expect(orders.single['total'], 1499.0);
    expect(orders.single['items'], hasLength(1));

    await tester.tap(navTab('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réserver').first);
    await tester.pumpAndSettle();
    // Formulaire prérempli avec le compte connecté.
    expect(find.text('Testeur Profile'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Saisissez votre nom.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), 'ada@example.com');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CT-'), findsOneWidget);
    final reservations = await CrowdTechDatabase.getItems('reservations');
    expect(reservations, hasLength(1));
    expect(reservations.single['attendeeName'], 'Ada Lovelace');
    expect(reservations.single['ticket'], startsWith('CT-'));
  });

  testWidgets('each article has its own discussion and validates comments', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/news', arguments: testAdmin));
    await tester.pumpAndSettle();

    // Discussion du premier article (« L’IA générative… »).
    final discussion = find.text('Discussion').first;
    await tester.scrollUntilVisible(
      discussion,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(discussion);
    await tester.pumpAndSettle();
    expect(find.text('Aucun commentaire sur cette actualité.'), findsOneWidget);
    await tester.tap(find.text('Commenter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'court');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Saisissez au moins 10 caractères.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).last,
      'https://example.com article',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(
      find.text('Les liens sont filtrés dans cette démonstration.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextFormField).last,
      'Analyse intéressante de cette actualité.',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Analyse intéressante de cette actualité.'),
      findsOneWidget,
    );
    final news = await CrowdTechDatabase.getItems('news');
    final iaArticle = news.firstWhere(
      (item) => item['title'] == 'L’IA générative transforme le développement',
    );
    final comment = (await CrowdTechDatabase.getItems('news_comments')).single;
    expect(comment['text'], 'Analyse intéressante de cette actualité.');
    expect(comment['articleId'], iaArticle['id']);

    // De retour à la liste : seul cet article compte un commentaire.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discussion (1)'), findsOneWidget);
  });

  testWidgets('articles are rated with stars and an optional review', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/news', arguments: testAdmin));
    await tester.pumpAndSettle();

    final rate = find.text('Noter').first;
    await tester.scrollUntilVisible(
      rate,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(rate);
    await tester.pumpAndSettle();

    // Sans étoile : refusé. L’avis, lui, n’est pas obligatoire.
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Choisissez une note de 1 à 5 étoiles.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('star-4')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final vote = (await CrowdTechDatabase.getItems('news_votes')).single;
    expect(vote['stars'], 4);
    expect(vote['review'], '');
    final rated = (await CrowdTechDatabase.getItems('news'))
        .firstWhere((item) => item['id'] == vote['articleId']);
    // 4 étoiles = 80 %, pondéré par la source : (96×3 + 80) / 4 = 92 %.
    expect(rated['credibility'], 92);
    expect(find.text('Ma note : 4'), findsOneWidget);
    expect(find.text('4.0 · 1 avis'), findsOneWidget);
  });

  testWidgets('profile edit validates and updates the displayed details', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton).first);
    await pumpDatabaseAndSettle(tester);
    await tester.tap(navTab('Profil'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Modifier mon profil'));
    await tester.tap(find.text('Modifier mon profil'));
    await tester.pumpAndSettle();
    await fillProfileRequired(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Grace Hopper');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Email invalide.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'grace@example.com',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('grace@example.com'), findsOneWidget);
    final profiles = await CrowdTechDatabase.getItems('profiles');
    expect(profiles, hasLength(1));
    expect(profiles.single['name'], 'Grace Hopper');
    expect(profiles.single['email'], 'grace@example.com');
  });

  testWidgets('registration validates required fields and password match', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await prepareDemoDatabase();
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Rejoignez CrowdTech'), findsOneWidget);
    // Formulaire vide : les champs obligatoires sont signalés.
    await submitRegistration(tester);
    expect(find.text('Nom requis.'), findsOneWidget);
    expect(find.text('Email requis.'), findsOneWidget);
    expect(find.text('Mot de passe requis.'), findsOneWidget);
    expect(find.text('Date de naissance requise.'), findsOneWidget);
    expect(find.text('Téléphone requis.'), findsOneWidget);
    expect(find.text('Code postal requis.'), findsOneWidget);

    // Mots de passe différents, âge trop jeune, conditions refusées.
    await fillRegistrationForm(
      tester,
      birthDate: '01/01/2020',
      password: 'password1',
      confirm: 'different1',
      acceptTerms: false,
    );
    await submitRegistration(tester);
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(find.text('Vous devez avoir au moins 16 ans.'), findsOneWidget);
    expect(
      find.text('Veuillez accepter les conditions d’utilisation.'),
      findsOneWidget,
    );
  });
}
