// Données des comptes (empreintes de mots de passe, jamais en clair).

import 'package:crowdtech/core/database/collection_repository.dart';

abstract final class AccountRepository {
  static const accounts = CollectionRepository('accounts');
}
