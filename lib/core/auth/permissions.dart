// Droits d'accès selon le rôle de l'utilisateur connecté.
//
// | Action                                         | Qui peut ?                 |
// |------------------------------------------------|----------------------------|
// | Lire, commenter, acheter, investir, réserver   | Tout le monde              |
// | Publier une actualité, vendre un produit       | Tout le monde              |
// | Publier un projet, organiser un événement      | Porteur de projet, Admin   |
// | Modifier / supprimer un élément                | Son auteur, Admin          |
// | Packs de jetons, rôles, import, contrôle billets | Admin uniquement         |

import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';

class Permissions {
  Permissions._();

  static bool get isAdmin => CrowdTechSession.role == UserRoles.admin;

  static bool get canPublishProjects =>
      isAdmin || CrowdTechSession.role == UserRoles.projectOwner;

  static bool get canOrganizeEvents => canPublishProjects;

  /// L'utilisateur peut modifier ou supprimer cet élément s'il en est
  /// l'auteur, ou s'il est administrateur.
  static bool canManage(Map<String, Object?> record) =>
      isAdmin ||
      (CrowdTechSession.accountKey != null &&
          record['ownerKey'] == CrowdTechSession.accountKey);

  /// Message affiché quand une action est refusée.
  static const adminOnlyMessage = 'Accès réservé à l’administrateur.';
}
