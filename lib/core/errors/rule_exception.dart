// Erreur métier commune à tous les modules : les règles et les écrans s'en
// servent sans dépendre de la base de données.

/// Action refusée par une règle métier (stock insuffisant, suppression
/// impossible…). Le message est affiché tel quel à l'utilisateur.
class RuleException implements Exception {
  final String message;
  const RuleException(this.message);

  @override
  String toString() => message;
}
