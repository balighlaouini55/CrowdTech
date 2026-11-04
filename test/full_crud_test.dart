import 'dart:async';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

/// Vérification complète : ajout, lecture, modification et suppression dans
/// toutes les gestions, sur une vraie base SQLite puis par l’interface.
void main() {
  // -------------------------------------------------------------------------
  // 1. Vraie base SQLite (fichier sur disque)
  group('Base SQLite réelle', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      CrowdTechDatabase.databaseFileName = 'crowdtech_verification.db';
    });
    setUp(() async {
      CrowdTechSession.accountKey = 'verif@crowdtech.app';
      await CrowdTechDatabase.resetForTesting();
    });
    tearDownAll(CrowdTechDatabase.resetForTesting);

    const samples = <String, Map<String, Object?>>{
      'news': {
        'title': 'Article',
        'source': 'Source',
        'credibility': 0,
        'tag': 'IA',
        'summary': 'Résumé de test suffisamment long.',
        'author': 'Auteur',
        'url': 'https://example.com',
        'publishedAt': '2026-11-01',
      },
      'funding': {
        'title': 'Projet',
        'company': 'Entreprise',
        'amountRaised': 0.0,
        'goal': 1000.0,
        'tokenPrice': 10.0,
        'progress': 0,
        'feature': 'Fonction',
        'category': 'IA',
        'deadline': '2030-12-31',
      },
      'products': {
        'name': 'Produit',
        'price': 99.0,
        'rating': null,
        'category': 'Accessoire',
        'brand': 'Marque',
        'stock': 4,
        'condition': 'Neuf',
      },
      'events': {
        'title': 'Événement',
        'date': '12/12/2030',
        'city': 'Paris',
        'seats': 20,
        'time': '10:00',
        'venue': 'Salle A',
        'price': 15.0,
        'category': 'Atelier',
      },
      'token_packs': {
        'name': 'Pack test',
        'tokens': 10,
        'bonusPercent': 5,
        'discountPercent': 0,
        'highlighted': false,
      },
      'profiles': {
        'accountKey': 'verif@crowdtech.app',
        'name': 'Vérif',
        'email': 'verif@crowdtech.app',
        'phone': '+216 20 123 456',
        'city': 'Tunis',
      },
      'news_comments': {'text': 'Un commentaire de test.'},
      'cart': {'productId': 1, 'productName': 'Produit', 'quantity': 1},
      'reservations': {
        'eventId': 1,
        'eventTitle': 'Événement',
        'attendeeName': 'Ada',
        'ticket': 'CT-1',
      },
      'simulations': {'title': 'Simulation', 'amount': 100.0},
    };

    for (final MapEntry(key: collection, value: sample) in samples.entries) {
      test('CRUD complet : $collection', () async {
        // Ajout
        final id = await CrowdTechDatabase.insertItem(collection, sample);
        expect(id, greaterThan(0));
        // Lecture : tous les champs sont relus à l’identique
        final saved = (await CrowdTechDatabase.getItems(collection)).single;
        for (final MapEntry(:key, :value) in sample.entries) {
          expect(saved[key], value, reason: '$collection.$key');
        }
        // Modification
        final updated = {...sample, 'modifié': true};
        expect(await CrowdTechDatabase.updateItem(collection, id, updated), 1);
        expect(
          (await CrowdTechDatabase.getItems(collection)).single['modifié'],
          isTrue,
        );
        // Persistance après fermeture / réouverture du fichier
        await CrowdTechDatabase.close();
        expect(
          (await CrowdTechDatabase.getItems(collection)).single['modifié'],
          isTrue,
        );
        // Suppression
        expect(await CrowdTechDatabase.deleteItem(collection, id), 1);
        expect(await CrowdTechDatabase.getItems(collection), isEmpty);
        // Journal : ajout, modification, suppression tracés
        final actions = (await CrowdTechDatabase.getItems('activity_log'))
            .map((entry) => entry['action'] as String)
            .toList();
        expect(actions.where((a) => a.startsWith('Ajout')), hasLength(1));
        expect(
          actions.where((a) => a.startsWith('Modification')),
          hasLength(1),
        );
        expect(actions.where((a) => a.startsWith('Suppression')), hasLength(1));
      });
    }

    test(
      'achat de pack : projet et investissement dans une transaction',
      () async {
        final projectId = await CrowdTechDatabase.insertItem(
          'funding',
          samples['funding']!,
        );
        await CrowdTechDatabase.saveInvestment(
          projectId: projectId,
          updatedProject: {...samples['funding']!, 'amountRaised': 200.0},
          investment: {
            'projectTitle': 'Projet',
            'pack': 'Supporter',
            'tokens': 21,
            'amount': 200.0,
          },
        );
        await CrowdTechDatabase.close();
        expect(
          (await CrowdTechDatabase.getItems('funding')).single['amountRaised'],
          200.0,
        );
        expect(
          (await CrowdTechDatabase.getItems('investments')).single['tokens'],
          21,
        );
      },
    );

    test('commande : panier vidé et stock diminué', () async {
      final productId = await CrowdTechDatabase.insertItem(
        'products',
        samples['products']!,
      );
      await CrowdTechDatabase.insertItem('cart', {
        'productId': productId,
        'productName': 'Produit',
        'quantity': 3,
      });
      await CrowdTechDatabase.createOrderAndClearCart({
        'items': [
          {'productId': productId, 'productName': 'Produit', 'quantity': 3},
        ],
        'total': 297.0,
      });
      await CrowdTechDatabase.close();
      expect(await CrowdTechDatabase.getItems('cart'), isEmpty);
      expect((await CrowdTechDatabase.getItems('orders')), hasLength(1));
      expect((await CrowdTechDatabase.getItems('products')).single['stock'], 1);
    });

    test('comptes : inscription, connexion et persistance', () async {
      await AccountService.register(
        name: 'Nour',
        email: 'nour@example.com',
        password: 'secret123',
        role: 'Investisseur',
      );
      await CrowdTechDatabase.close();
      final user = await AccountService.login(
        email: 'nour@example.com',
        password: 'secret123',
      );
      expect(user.name, 'Nour');
      await AccountService.resetPassword(
        email: 'nour@example.com',
        newPassword: 'nouveau123',
      );
      await expectLater(
        AccountService.login(email: 'nour@example.com', password: 'secret123'),
        throwsA(isA<AccountException>()),
      );
      expect(
        (await AccountService.login(
          email: 'nour@example.com',
          password: 'nouveau123',
        )).email,
        'nour@example.com',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Par l’interface, comme un utilisateur
  group('Interface : ajouter, modifier, supprimer', () {
    setUp(() async {
      await CrowdTechDatabase.useMemoryForTesting();
      CrowdTechSession.accountKey = null;
    });

    Future<NavigatorState> startApp(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(const CrowdTechApp());
      await tester.pumpAndSettle();
      return tester.state<NavigatorState>(find.byType(Navigator).first);
    }

    Future<void> fill(WidgetTester tester, Map<int, String> values) async {
      for (final MapEntry(:key, :value) in values.entries) {
        await tester.enterText(find.byType(TextFormField).at(key), value);
      }
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(
      WidgetTester tester,
      String tooltip,
      String item,
    ) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    Future<void> recordAction(
      WidgetTester tester,
      String title,
      String action,
    ) async {
      final tile = find.ancestor(
        of: find.text(title),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(action).last);
      await tester.pumpAndSettle();
      if (action == 'Supprimer') {
        await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
        await tester.pumpAndSettle();
      }
    }

    Future<Map<String, Object?>?> findRecord(
      String collection,
      String key,
      String value,
    ) async =>
        (await CrowdTechDatabase.getItems(collection))
            .where((row) => row[key] == value)
            .firstOrNull;

    testWidgets('Actualités', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/news', arguments: testAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter une actualité'));
      await tester.pumpAndSettle();
      await fill(tester, {
        0: 'Actualité vérifiée',
        1: 'Source test',
        2: 'IA',
        3: 'Un résumé complet de l’actualité.',
        4: 'Amina',
        5: 'pas-un-lien',
        6: '15/10/2026',
      });
      await save(tester);
      expect(find.textContaining('http:// ou https://'), findsOneWidget);
      await fill(tester, {5: 'https://example.com/article'});
      await save(tester);
      final added = await findRecord('news', 'title', 'Actualité vérifiée');
      expect(added?['author'], 'Amina');
      expect(added?['url'], 'https://example.com/article');
      expect(added?['publishedAt'], '2026-10-15');

      await openMenu(
        tester,
        'Autres pages actualités',
        'Gérer tous les articles',
      );
      await recordAction(tester, 'Actualité vérifiée', 'Modifier');
      expect(find.text('Amina'), findsOneWidget); // formulaire pré-rempli
      await fill(tester, {0: 'Actualité modifiée', 4: 'Karim'});
      await save(tester);
      final edited = await findRecord('news', 'title', 'Actualité modifiée');
      expect(edited?['author'], 'Karim');
      expect(edited?['url'], 'https://example.com/article');

      await recordAction(tester, 'Actualité modifiée', 'Supprimer');
      expect(await findRecord('news', 'title', 'Actualité modifiée'), isNull);
    });

    testWidgets('Projets de crowdfunding', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/funding', arguments: testAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter un projet'));
      await tester.pumpAndSettle();
      await fill(tester, {
        0: 'Projet vérifié',
        1: 'Startup',
        2: '5000',
        3: '6000',
        4: 'Nouvelle fonctionnalité',
        5: 'Santé',
        6: 'Une description du projet.',
        7: '01/01/2020',
        8: 'Sfax',
        9: 'https://projet.example.com',
        10: '5',
        11: 'https://example.com/couverture.png',
      });
      await save(tester);
      expect(
        find.text('Le prix du jeton ne peut pas dépasser l’objectif.'),
        findsOneWidget,
      );
      expect(
        find.text('La date limite doit être aujourd’hui ou plus tard.'),
        findsOneWidget,
      );
      await fill(tester, {3: '50', 7: '31/12/2030'});
      await save(tester);
      final added = await findRecord('funding', 'title', 'Projet vérifié');
      expect(added?['category'], 'Santé');
      expect(added?['deadline'], '2030-12-31');
      expect(added?['tokenPrice'], 50.0);
      expect(added?['location'], 'Sfax');
      expect(added?['website'], 'https://projet.example.com');
      expect(added?['teamSize'], 5);
      expect(added?['stage'], 'Prototype');
      expect(added?['imageUrl'], 'https://example.com/couverture.png');

      await openMenu(
        tester,
        'Autres pages crowdfunding',
        'Gérer tous les projets',
      );
      await recordAction(tester, 'Projet vérifié', 'Modifier');
      await fill(tester, {0: 'Projet modifié', 2: '8000'});
      await save(tester);
      final edited = await findRecord('funding', 'title', 'Projet modifié');
      expect(edited?['goal'], 8000.0);
      expect(edited?['category'], 'Santé');

      await recordAction(tester, 'Projet modifié', 'Supprimer');
      expect(await findRecord('funding', 'title', 'Projet modifié'), isNull);
    });

    testWidgets('Packs de jetons', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/funding', arguments: testAdmin));
      await tester.pumpAndSettle();
      await openMenu(
        tester,
        'Autres pages crowdfunding',
        'Gérer les packs de jetons',
      );
      expect(find.text('Pack Découverte'), findsOneWidget);
      await tester.tap(find.text('Nouveau pack'));
      await tester.pumpAndSettle();
      await fill(tester, {0: 'Étudiant', 1: '15', 2: '10', 3: '5'});
      await save(tester);
      expect(
        (await findRecord('token_packs', 'name', 'Étudiant'))?['tokens'],
        15,
      );

      await recordAction(tester, 'Pack Étudiant', 'Modifier');
      await fill(tester, {1: '30'});
      await save(tester);
      expect(
        (await findRecord('token_packs', 'name', 'Étudiant'))?['tokens'],
        30,
      );

      await recordAction(tester, 'Pack Étudiant', 'Supprimer');
      expect(await findRecord('token_packs', 'name', 'Étudiant'), isNull);
    });

    testWidgets('Produits et panier', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/marketplace', arguments: testAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter un produit'));
      await tester.pumpAndSettle();
      await fill(tester, {
        0: 'Casque audio',
        1: 'Accessoire',
        2: '79.9',
        3: 'SoundLab',
        4: '2',
        5: 'Réduction de bruit active.',
      });
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconditionné').last);
      await tester.pumpAndSettle();
      await save(tester);
      final added = await findRecord('products', 'name', 'Casque audio');
      expect(added?['brand'], 'SoundLab');
      expect(added?['stock'], 2);
      expect(added?['condition'], 'Reconditionné');

      Finder addButtonOf(String name) => find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
        matching: find.byTooltip('Ajouter au panier'),
      );

      // On ne peut pas acheter son propre produit.
      await tester.tap(addButtonOf('Casque audio'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('vous ne pouvez pas l’acheter'),
        findsOneWidget,
      );
      expect(await findRecord('cart', 'productName', 'Casque audio'), isNull);

      // Le produit est confié à un autre vendeur : l’admin peut l’acheter.
      await CrowdTechDatabase.updateItem(
        'products',
        added!['id']! as int,
        {...added, 'ownerKey': 'vendeur@example.com'}..remove('id'),
      );
      navigator.pop();
      await tester.pumpAndSettle();
      unawaited(navigator.pushNamed('/marketplace', arguments: testAdmin));
      await tester.pumpAndSettle();

      // Panier : 2 en stock, le 3e ajout est refusé. Le produit ajouté est
      // en bas du catalogue : on le retrouve avec la recherche.
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Rechercher un produit, une marque, une catégorie',
        ),
        'Casque audio',
      );
      await tester.pumpAndSettle();
      final addButton = addButtonOf('Casque audio');
      for (var i = 0; i < 3; i++) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Stock insuffisant'), findsOneWidget);
      expect(
        (await findRecord('cart', 'productName', 'Casque audio'))?['quantity'],
        2,
      );

      await tester.tap(find.byTooltip('Ouvrir le panier'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter un exemplaire'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stock insuffisant'), findsWidgets);
      await tester.tap(find.byTooltip('Retirer un exemplaire'));
      await tester.pumpAndSettle();
      expect(
        (await findRecord('cart', 'productName', 'Casque audio'))?['quantity'],
        1,
      );
      await tester.tap(find.byTooltip('Retirer du panier'));
      await tester.pumpAndSettle();
      expect(await CrowdTechDatabase.getItems('cart'), isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openMenu(
        tester,
        'Autres pages marketplace',
        'Gérer tous les produits',
      );
      await recordAction(tester, 'Casque audio', 'Modifier');
      await fill(tester, {0: 'Casque modifié', 4: '7'});
      await save(tester);
      final edited = await findRecord('products', 'name', 'Casque modifié');
      expect(edited?['stock'], 7);
      expect(edited?['condition'], 'Reconditionné');

      await recordAction(tester, 'Casque modifié', 'Supprimer');
      expect(await findRecord('products', 'name', 'Casque modifié'), isNull);
    });

    testWidgets('Événements', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/events', arguments: testAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter un événement'));
      await tester.pumpAndSettle();
      await fill(tester, {
        0: 'Hackathon vérifié',
        1: '20/12/2030',
        2: 'Tunis',
        3: '50',
        4: '25:00',
        5: 'Technopole',
        6: '10',
        7: 'Deux jours de code.',
        8: 'https://example.com/hackathon.png',
      });
      await save(tester);
      expect(find.text('Heure invalide (ex. 09:30).'), findsOneWidget);
      await fill(tester, {4: '09:30'});
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hackathon').last);
      await tester.pumpAndSettle();
      await save(tester);
      final added = await findRecord('events', 'title', 'Hackathon vérifié');
      expect(added?['time'], '09:30');
      expect(added?['price'], 10.0);
      expect(added?['category'], 'Hackathon');
      expect(added?['venue'], 'Technopole');
      expect(added?['imageUrl'], 'https://example.com/hackathon.png');

      await openMenu(
        tester,
        'Autres pages événements',
        'Gérer tous les événements',
      );
      await recordAction(tester, 'Hackathon vérifié', 'Modifier');
      await fill(tester, {0: 'Hackathon modifié', 6: '0'});
      await save(tester);
      final edited = await findRecord('events', 'title', 'Hackathon modifié');
      expect(edited?['price'], 0.0);
      expect(edited?['category'], 'Hackathon');

      await recordAction(tester, 'Hackathon modifié', 'Supprimer');
      expect(await findRecord('events', 'title', 'Hackathon modifié'), isNull);
    });

    testWidgets('Profil', (tester) async {
      final navigator = await startApp(tester);
      unawaited(navigator.pushNamed('/profile', arguments: testAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier mon profil'));
      await tester.pumpAndSettle();
      await fillProfileRequired(tester);
      await fill(tester, {
        0: 'Sami Ben Salah',
        1: 'sami@example.com',
        2: '12',
        5: 'Sfax',
        7: 'ISET',
        8: 'Passionné de tech.',
      });
      await save(tester);
      expect(find.textContaining('Numéro invalide'), findsOneWidget);
      await fill(tester, {2: '+216 20 123 456'});
      await save(tester);
      expect(find.textContaining('3000 Sfax'), findsOneWidget);
      expect(find.text('ISET'), findsOneWidget);
      final profile = (await CrowdTechDatabase.getItems('profiles')).single;
      expect(profile['name'], 'Sami Ben Salah');
      expect(profile['phone'], '+216 20 123 456');
      expect(profile['bio'], 'Passionné de tech.');

      // Le formulaire se ré-ouvre avec les valeurs enregistrées.
      await tester.tap(find.text('Modifier mon profil'));
      await tester.pumpAndSettle();
      expect(find.text('+216 20 123 456'), findsOneWidget);
      expect(find.text('Passionné de tech.'), findsOneWidget);
    });
  });
}
