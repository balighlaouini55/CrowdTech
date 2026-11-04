// Essai de bout en bout dans la vraie application Windows : vraie base SQLite
// et vraies API gratuites, sans Firebase ni notifications système.
//
// La base réelle de l'utilisateur ne doit jamais être touchée : l'essai s'arrête
// si APPDATA ne pointe pas vers un dossier temporaire « crowdtech-e2e ».
//
//   $env:APPDATA = "$env:TEMP\crowdtech-e2e"
//   $env:CROWDTECH_SHOTS = "$env:TEMP\crowdtech-e2e\captures"
//   flutter test integration_test/parcours_test.dart -d windows

import 'dart:io';
import 'dart:ui' as ui;

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_helpers.dart';

/// Laisse l'application travailler (réseau, animations) en temps réel.
Future<void> wait(WidgetTester tester, [int seconds = 3]) async {
  for (var i = 0; i < seconds * 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// Enregistre une capture de la fenêtre.
Future<void> shot(WidgetTester tester, String name) async {
  final folder = Platform.environment['CROWDTECH_SHOTS'];
  if (folder == null) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(folder).create(recursive: true);
    await File('$folder/$name.png')
        .writeAsBytes(data!.buffer.asUint8List(), flush: true);
  });
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(target);
  await wait(tester, 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final appData = Platform.environment['APPDATA'] ?? '';
    if (!appData.contains('crowdtech-e2e')) {
      throw StateError('APPDATA doit pointer vers un dossier crowdtech-e2e.');
    }
  });

  testWidgets('inscription, puis visite des cinq espaces', (tester) async {
    final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.pumpWidget(const CrowdTechApp());
    await wait(tester);
    await shot(tester, '01_accueil');

    await tapText(tester, 'Créer un compte');
    await fillRegistrationForm(
      tester,
      email: email,
      password: 'Zx9-Ct-e2e-Lm42-qRt',
    );
    await shot(tester, '02_inscription');
    await tester.ensureVisible(find.text('S’inscrire'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('S’inscrire'));
    await wait(tester, 8);
    await shot(tester, '03_apres_inscription');
    expect(find.text('S’inscrire'), findsNothing);

    for (final (index, tab) in [
      'Actus',
      'Crowd',
      'Store',
      'Événements',
      'Profil',
    ].indexed) {
      await tapText(tester, tab);
      await wait(tester, 4);
      await shot(tester, '1${index}_$tab');
    }

    // Réservation réelle : le badge enregistré doit être chiffré.
    await tapText(tester, 'Événements');
    await wait(tester, 2);
    final reserve = find.textContaining('Réserver');
    expect(reserve, findsWidgets, reason: 'aucun événement réservable');
    await tester.ensureVisible(reserve.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(reserve.first);
    await wait(tester);
    await shot(tester, '20_reservation');
    final confirm = find.descendant(
      of: find.byType(Form),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget.enabled,
      ),
    );
    await tester.ensureVisible(confirm.last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(confirm.last);
    await wait(tester, 5);
    await shot(tester, '21_billet');
    final reservations = await CrowdTechDatabase.getItems('reservations');
    expect(reservations.where((row) => row['ownerKey'] == email), hasLength(1));
    expect(
      reservations.firstWhere((row) => row['ownerKey'] == email)['badge'],
      startsWith('CTB2.'),
    );
    await AccountService.logout();
  });

  testWidgets('le mot de passe par défaut de l’admin doit être changé', (
    tester,
  ) async {
    await tester.pumpWidget(const CrowdTechApp());
    await wait(tester);
    await tapText(tester, 'Se connecter');
    await tester.enterText(
      fieldLabeled('Email'),
      AccountService.defaultAdminEmail,
    );
    await tester.enterText(
      fieldLabeled('Mot de passe'),
      AccountService.defaultAdminPassword,
    );
    final login = find.byType(ElevatedButton).first;
    await tester.ensureVisible(login);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(login);
    await wait(tester, 4);
    await shot(tester, '30_admin_changement_obligatoire');
    expect(find.textContaining('mot de passe par défaut'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Zx9-Admin-e2e-Lm42');
    await tester.enterText(fields.at(2), 'Zx9-Admin-e2e-Lm42');
    await tapText(tester, 'Changer le mot de passe');
    await wait(tester, 4);
    await shot(tester, '31_admin_connecte');
    expect(find.textContaining('mot de passe par défaut'), findsNothing);
    expect(
      find.byType(NavigationBar).evaluate().isNotEmpty ||
          find.byType(NavigationRail).evaluate().isNotEmpty,
      isTrue,
    );
    await AccountService.logout();
  });
}
