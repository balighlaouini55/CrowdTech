// Garde-fous du refactoring : lecture directe par identifiant, dialogues
// qui libèrent leurs contrôleurs après l'animation de fermeture, messages
// communs.

import 'package:crowdtech/core/database/collection_repository.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('byId lit un seul élément, dans la bonne collection', () async {
    await CrowdTechDatabase.useMemoryForTesting();
    const products = CollectionRepository('products');
    const events = CollectionRepository('events');
    final id = await products.add({'name': 'Clavier'});
    await events.add({'title': 'Meetup'});

    expect((await products.byId(id))?['name'], 'Clavier');
    expect(await events.byId(id), isNull);
    expect(await products.byId(999), isNull);
    // La copie retournée ne modifie pas la base.
    (await products.byId(id))!['name'] = 'modifié';
    expect((await products.byId(id))?['name'], 'Clavier');
  });

  Widget host(Future<void> Function(BuildContext context) onTap) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => onTap(context),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );

  testWidgets('dialogue de saisie : valeurs, annulation, fermeture propre', (
    tester,
  ) async {
    List<String>? result = ['pas encore'];
    await tester.pumpWidget(
      host((context) async {
        result = await showInputDialog(
          context,
          title: 'Motif',
          fields: const [
            DialogField('Raison', hint: 'Ex. : trop cher', multiline: true),
          ],
        );
      }),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Ex. : trop cher'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Doublon');
    await tester.tap(find.text('Enregistrer'));
    // Toute l'animation de fermeture : aucune erreur de contrôleur libéré.
    await tester.pumpAndSettle();
    expect(result, ['Doublon']);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('message commun en bas de l’écran', (tester) async {
    await tester.pumpWidget(
      host((context) async => context.showMessage('Projet enregistré.')),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    expect(find.text('Projet enregistré.'), findsOneWidget);
  });
}
