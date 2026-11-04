// Numérotation partagée entre appareils, utilisée quand Firebase est
// configuré : un même élément porte le même identifiant sur tous les
// téléphones, ce qui garde valides les liens entre éléments (une note pointe
// vers son article, une réservation vers son événement…).
//
// Plages d'identifiants :
//   < 1 000 000 000            numérotation locale de SQLite (non partagée) ;
//   1 000 000 000 …            exemples de démonstration (même liste, mêmes
//                              numéros sur tous les appareils) ;
//   10 000 000 000 …           éléments importés d'Internet (numéro calculé
//                              à partir de leur clé : pas de doublon) ;
//   ≈ 180 000 000 000 000 …    éléments créés (horodatage + hasard).
// Tous restent sous 2⁵³ : exacts aussi dans la version Web.

import 'dart:math';

class SharedIds {
  SharedIds({Random? random, DateTime Function()? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? DateTime.now;

  static const firstShared = 1000000000;
  static const _firstImported = 10000000000;
  static const _importedSpan = 90000000000000;

  /// Collections de démonstration : chacune a sa plage de numéros.
  static const _seedSlots = {
    'news': 1,
    'funding': 2,
    'token_packs': 3,
    'products': 4,
    'events': 5,
  };

  final Random _random;
  final DateTime Function() _clock;
  int _last = 0;

  /// Vrai pour un identifiant partagé (synchronisable entre appareils).
  static bool isShared(Object? id) => id is int && id >= firstShared;

  /// Nouvel identifiant unique : millisecondes × 100 + hasard (0–99), et
  /// toujours croissant sur un même appareil.
  int next() {
    final candidate =
        _clock().millisecondsSinceEpoch * 100 + _random.nextInt(100);
    _last = max(candidate, _last + 1);
    return _last;
  }

  /// Identifiant du [index]-ième exemple de démonstration de [collection].
  int seed(String collection, int index) =>
      firstShared +
      (_seedSlots[collection] ?? 9000 + _hash(collection) % 900) * 100000 +
      index;

  /// Identifiant d'un élément importé, déduit de sa clé unique (même
  /// article importé sur deux téléphones = même identifiant).
  int imported(String collection, String key) =>
      _firstImported +
      _hash('$collection/${key.toLowerCase()}') % _importedSpan;

  /// Empreinte sur 52 bits, stable sur toutes les plateformes (contrairement
  /// à String.hashCode) : deux empreintes FNV-1a de 32 bits combinées.
  static int _hash(String text) =>
      _fnv32(text, 0x811c9dc5) * 0x100000 +
      (_fnv32(text, 0x050c5d1f) & 0xFFFFF);

  /// FNV-1a 32 bits. Le produit par le nombre premier 2²⁴ + 403 est découpé
  /// pour rester exact sous 2⁵³, donc identique dans la version Web.
  static int _fnv32(String text, int offset) {
    var hash = offset;
    for (final unit in text.codeUnits) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash * 403 + (hash & 0xFF) * 0x1000000) % 0x100000000;
    }
    return hash;
  }
}
