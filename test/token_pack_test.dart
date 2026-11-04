import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/funding/presentation/funding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Investir ouvre les packs de jetons et achète un pack', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    useTallScreen(tester);
    await tester.pumpWidget(
      const MaterialApp(home: FundingScreen(accountKey: 'nouveau@test.app')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Investir').first);
    await tester.pumpAndSettle();

    expect(find.text('Choisissez un pack de jetons'), findsOneWidget);
    for (final name in ['Découverte', 'Supporter', 'Premium', 'Fondateur']) {
      await tester.scrollUntilVisible(find.text('Pack $name'), 200);
      expect(find.text('Pack $name'), findsOneWidget);
    }

    await tester.tap(find.text('Pack Fondateur'));
    await tester.pump();
    await tester.tap(find.textContaining('Acheter le pack Fondateur'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pack Fondateur acheté : 120'), findsOneWidget);
  });
}
