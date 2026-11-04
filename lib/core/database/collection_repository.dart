// Accès aux données d'une collection : lecture, ajout, modification,
// suppression. Les écrans et les règles métier passent par les dépôts des
// modules (NewsRepository, FundingRepository…) au lieu d'appeler la base
// directement : changer de stockage ne touche qu'ici.

import 'package:crowdtech/core/database/crowdtech_database.dart';

/// Une ligne de la base : champ → valeur.
typedef DataRow = Map<String, Object?>;

class CollectionRepository {
  final String collection;
  const CollectionRepository(this.collection);

  /// Tous les éléments, dans l'ordre d'enregistrement.
  Future<List<DataRow>> all() => CrowdTechDatabase.getItems(collection);

  /// Éléments qui vérifient [test].
  Future<List<DataRow>> where(bool Function(DataRow row) test) async =>
      (await all()).where(test).toList();

  /// Éléments créés par un compte (champ `ownerKey`).
  Future<List<DataRow>> ownedBy(String accountKey) =>
      where((row) => row['ownerKey'] == accountKey);

  /// Élément d'identifiant [id], ou null.
  Future<DataRow?> byId(int id) => CrowdTechDatabase.getItem(collection, id);

  /// Ajoute un élément et retourne son identifiant.
  Future<int> add(DataRow data) =>
      CrowdTechDatabase.insertItem(collection, data);

  /// Remplace un élément ; retourne le nombre de lignes modifiées (0 ou 1).
  Future<int> update(int id, DataRow data) =>
      CrowdTechDatabase.updateItem(collection, id, data);

  /// Supprime un élément (et ses éléments liés, voir CrowdTechDatabase).
  Future<int> remove(int id) => CrowdTechDatabase.deleteItem(collection, id);

  /// Contenu de démonstration inséré une seule fois, puis éléments lus.
  Future<List<DataRow>> seeded(List<DataRow> defaults) =>
      CrowdTechDatabase.loadSeededItems(collection, defaults);

  /// Import depuis Internet sans doublon (comparaison sur [uniqueKey]).
  Future<int> import(List<DataRow> items, {required String uniqueKey}) =>
      CrowdTechDatabase.importItems(collection, items, uniqueKey: uniqueKey);
}
