// Calcul de la livraison : frais et délai selon la distance routière, et
// vérification que le code postal correspond bien à la ville.

/// Devis de livraison.
class DeliveryQuote {
  final double km;
  final double hours;
  final double cost;
  final int days;
  const DeliveryQuote({
    required this.km,
    required this.hours,
    required this.cost,
    required this.days,
  });

  /// Forfait de départ, prix au kilomètre et plafond (€).
  static const baseCost = 4.0;
  static const perKm = 0.02;
  static const maxCost = 25.0;

  /// Livraison offerte à partir de ce montant d'achat (€).
  static const freeFrom = 500.0;

  /// Distance parcourue par jour de transport (km).
  static const kmPerDay = 350.0;

  /// Frais : 4 € + 0,02 €/km, plafonnés à 25 €, offerts dès 500 € d'achat.
  /// Délai : 1 jour de préparation + 1 jour par tranche de 350 km.
  factory DeliveryQuote.fromRoute({
    required double km,
    required double hours,
    double orderTotal = 0,
  }) {
    final cost = orderTotal >= freeFrom
        ? 0.0
        : (baseCost + km * perKm).clamp(baseCost, maxCost);
    return DeliveryQuote(
      km: km,
      hours: hours,
      cost: double.parse(cost.toStringAsFixed(2)),
      days: 1 + (km / kmPerDay).ceil().clamp(1, 10),
    );
  }

  bool get isFree => cost == 0;

  Map<String, Object?> toMap() => {
    'km': double.parse(km.toStringAsFixed(1)),
    'cost': cost,
    'days': days,
  };
}

class PostalCheck {
  PostalCheck._();

  /// Texte sans accents ni tirets, en minuscules : « Gabès » → « gabes ».
  static String normalize(String text) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp("[-_’']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Vrai si [city] fait partie des lieux du code postal (ville, région ou
  /// gouvernorat : « Sfax » correspond à « Gouvernorat Sfax »).
  static bool matches(String city, List<String> places) {
    final wanted = normalize(city);
    if (wanted.isEmpty) return false;
    return places
        .map(normalize)
        .any(
          (place) =>
              place == wanted ||
              place.split(' ').contains(wanted) ||
              wanted.split(' ').contains(place),
        );
  }
}
