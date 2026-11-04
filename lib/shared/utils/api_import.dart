// Lance un import HTTP → SQLite et affiche le résultat à l’utilisateur.

import 'package:flutter/material.dart';

/// Lance une synchronisation HTTP → SQLite et affiche le résultat.
/// [run] retourne le nombre d’éléments ajoutés ou mis à jour.
Future<void> runApiImport(
  BuildContext context, {
  required Future<int> Function() run,
  required Future<void> Function() reload,
  String successLabel = 'élément(s) importé(s) depuis Internet',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Connexion au serveur…')),
  );
  try {
    final count = await run();
    await reload();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Déjà à jour : rien de nouveau.'
                : '$count $successLabel.',
          ),
        ),
      );
  } on Exception catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Échec de l’import : $error')));
  }
}
