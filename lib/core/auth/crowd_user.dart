// Modèle : l'utilisateur connecté (nom, email, rôle) et la liste des rôles.

class CrowdUser {
  final String name;
  final String email;
  final String role;

  const CrowdUser({
    required this.name,
    required this.email,
    required this.role,
  });
}

/// Rôles possibles. Seul l'administrateur peut changer le rôle d'un compte.
class UserRoles {
  UserRoles._();

  static const reader = 'Lecteur';
  static const investor = 'Investisseur';
  static const projectOwner = 'Porteur de projet';
  static const admin = 'Admin';

  /// Rôles proposés à l'inscription (jamais Admin).
  static const selfService = [reader, investor, projectOwner];
  static const all = [reader, investor, projectOwner, admin];
}
