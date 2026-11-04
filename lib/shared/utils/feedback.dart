// Messages courts affichés en bas de l'écran après une action (succès,
// erreur, information), avec le style du thème.

import 'package:flutter/material.dart';

extension FeedbackMessages on BuildContext {
  /// Affiche [message] dans une barre en bas de l'écran.
  void showMessage(String message) =>
      ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
}
