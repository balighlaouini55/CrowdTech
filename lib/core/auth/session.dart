// Utilisateur connecté : son email (pour attribuer les opérations) et son rôle
// (pour savoir ce qu'il a le droit de faire, voir permissions.dart).

import 'package:crowdtech/core/auth/crowd_user.dart';

class CrowdTechSession {
  CrowdTechSession._();

  static String? accountKey;
  static String role = UserRoles.reader;

  /// Nom affiché, par exemple comme auteur des commentaires.
  static String? name;

  /// Enregistre l'utilisateur qui vient de se connecter.
  static void start(CrowdUser user) {
    accountKey = user.email;
    role = user.role;
    name = user.name;
  }

  static void clear() {
    accountKey = null;
    role = UserRoles.reader;
    name = null;
  }
}
