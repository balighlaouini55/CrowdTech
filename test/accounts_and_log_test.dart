import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/profile/presentation/activity_log_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  setUp(() async {
    CrowdTechSession.accountKey = null;
    await CrowdTechDatabase.useMemoryForTesting();
  });

  test('un compte est enregistré avec un mot de passe chiffré', () async {
    final user = await AccountService.register(
      name: 'Amina',
      email: ' Amina@Example.com ',
      password: 'motdepasse1',
      role: 'Investisseur',
    );
    expect(user.email, 'amina@example.com');

    final account = (await CrowdTechDatabase.getItems('accounts'))
        .firstWhere((row) => row['email'] == 'amina@example.com');
    expect(account['email'], 'amina@example.com');
    expect(account.values, isNot(contains('motdepasse1')));
    expect(account['passwordHash'], hasLength(64));

    expect(
      () => AccountService.register(
        name: 'Autre',
        email: 'amina@example.com',
        password: 'motdepasse2',
        role: 'Lecteur',
      ),
      throwsA(isA<AccountException>()),
    );

    await expectLater(
      AccountService.login(email: 'amina@example.com', password: 'mauvais1'),
      throwsA(isA<AccountException>()),
    );
    final logged = await AccountService.login(
      email: 'AMINA@example.com',
      password: 'motdepasse1',
    );
    expect(logged.name, 'Amina');
    expect(logged.role, 'Investisseur');
  });

  test('chaque opération est inscrite au journal de l’utilisateur', () async {
    CrowdTechSession.accountKey = 'amina@example.com';
    final id = await CrowdTechDatabase.insertItem('events', {'title': 'Forum'});
    await CrowdTechDatabase.updateItem('events', id, {'title': 'Forum IA'});
    await CrowdTechDatabase.deleteItem('events', id);
    await CrowdTechDatabase.importItems('news', [
      {'title': 'A'},
    ], uniqueKey: 'title');
    await CrowdTechDatabase.createOrderAndClearCart({'total': 42.0});

    final log = await CrowdTechDatabase.getItems('activity_log');
    expect(log.map((entry) => entry['action']), [
      'Ajout événement',
      'Modification événement',
      'Suppression événement',
      'Import Internet',
      'Commande validée',
    ]);
    expect(log.first['details'], 'Forum');
    expect(log[2]['details'], 'Forum IA');
    expect(
      log.every((entry) => entry['ownerKey'] == 'amina@example.com'),
      true,
    );
  });

  testWidgets('inscription, email déjà utilisé et historique', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const CrowdTechApp());
    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    Future<void> fillRegistration(String email) async {
      await fillRegistrationForm(tester, email: email);
      await submitRegistration(tester);
    }

    await AccountService.register(
      name: 'Déjà là',
      email: 'pris@example.com',
      password: 'secret123',
      role: 'Lecteur',
    );
    await fillRegistration('pris@example.com');
    expect(find.text('Un compte existe déjà avec cet email.'), findsOneWidget);

    await fillRegistration('sami@example.com');
    expect(find.byType(NavigationBar), findsOneWidget);
    final sami = (await CrowdTechDatabase.getItems('accounts'))
        .firstWhere((account) => account['email'] == 'sami@example.com');
    // Les informations de l'inscription sont enregistrées avec le compte.
    expect(sami['birthDate'], '2000-04-15');
    expect(sami['phone'], '+216 20 123 456');
    expect(sami['address'], '12 rue de la Liberté');
    expect(sami['city'], 'Tunis');
    expect(sami['postalCode'], '1002');
    expect(sami['country'], 'Tunisie');

    await tester.pumpWidget(
      const MaterialApp(home: ActivityLogPage(accountKey: 'sami@example.com')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ajout compte'), findsOneWidget);
  });
}
