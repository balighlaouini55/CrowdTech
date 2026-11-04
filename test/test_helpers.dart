import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran de test plus haut que le 800×600 par défaut, pour que les cartes
/// placées sous l’en-tête des écrans restent visibles.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Administrateur utilisé par les tests qui ouvrent les pages de gestion.
const testAdmin = CrowdUser(
  name: 'Admin test',
  email: 'admin@crowdtech.app',
  role: UserRoles.admin,
);

/// Champ de formulaire trouvé par son libellé (ex. « Email »).
Finder fieldLabeled(String label) => find.widgetWithText(TextFormField, label);

/// Remplit tout le formulaire d'inscription (sans l'envoyer).
Future<void> fillRegistrationForm(
  WidgetTester tester, {
  String name = 'Sami Ben Ali',
  String email = 'sami@example.com',
  String birthDate = '15/04/2000',
  String password = 'secret123',
  String? confirm,
  bool acceptTerms = true,
}) async {
  await tester.enterText(fieldLabeled('Nom complet'), name);
  await tester.enterText(fieldLabeled('Date de naissance'), birthDate);
  await tester.enterText(fieldLabeled('Email'), email);
  await tester.enterText(fieldLabeled('Téléphone'), '+216 20 123 456');
  await tester.enterText(fieldLabeled('Adresse'), '12 rue de la Liberté');
  await tester.enterText(fieldLabeled('Ville'), 'Tunis');
  await tester.enterText(fieldLabeled('Code postal'), '1002');
  // Le pays est facultatif : il est choisi dans la liste.
  final country = find.text('Non précisé');
  if (country.evaluate().isNotEmpty) {
    await tester.ensureVisible(country);
    await tester.pumpAndSettle();
    await tester.tap(country);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunisie').last);
    await tester.pumpAndSettle();
  }
  await tester.enterText(fieldLabeled('Mot de passe'), password);
  await tester.enterText(fieldLabeled('Confirmer'), confirm ?? password);
  if (acceptTerms) {
    final terms = find.byType(CheckboxListTile);
    await tester.ensureVisible(terms);
    await tester.pumpAndSettle();
    if (tester.widget<CheckboxListTile>(terms).value != true) {
      await tester.tap(terms);
      await tester.pumpAndSettle();
    }
  }
}

/// Appuie sur « S’inscrire ».
Future<void> submitRegistration(WidgetTester tester) async {
  // Laisse d'abord se terminer le défilement vers le champ actif.
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('S’inscrire'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('S’inscrire'));
  await tester.pumpAndSettle();
}

/// Remplit les coordonnées obligatoires de « Modifier mon profil »
/// (téléphone, date de naissance, adresse, ville, code postal, pays).
Future<void> fillProfileRequired(WidgetTester tester) async {
  await tester.enterText(fieldLabeled('Téléphone'), '+216 20 123 456');
  await tester.enterText(fieldLabeled('Date de naissance'), '15/04/2000');
  await tester.enterText(fieldLabeled('Adresse'), '12 rue de Sfax');
  await tester.enterText(fieldLabeled('Ville'), 'Sfax');
  await tester.enterText(fieldLabeled('Code postal'), '3000');
  // Pays : choisi dans la liste s'il n'est pas encore renseigné.
  final country = find.text('Choisir un pays');
  if (country.evaluate().isNotEmpty) {
    await tester.ensureVisible(country);
    await tester.pumpAndSettle();
    await tester.tap(country);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunisie').last);
    await tester.pumpAndSettle();
  }
}

/// Onglet de la barre de navigation principale (Accueil, Actus, Crowd,
/// Store, Agenda, Profil). Cherché dans la barre seulement : le tableau de
/// bord a aussi des raccourcis « Store » ou « Projets ».
Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
