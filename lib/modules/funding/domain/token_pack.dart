// Modèle : un pack de jetons (jetons achetés, bonus, réduction).

class TokenPack {
  final int? id;
  final String name;
  final int tokens;
  final int bonusPercent;
  final int discountPercent;
  final bool highlighted;
  const TokenPack({
    this.id,
    required this.name,
    required this.tokens,
    required this.bonusPercent,
    required this.discountPercent,
    this.highlighted = false,
  });

  factory TokenPack.fromMap(Map<String, Object?> map) => TokenPack(
    id: map['id'] as int?,
    name: map['name']! as String,
    tokens: (map['tokens']! as num).toInt(),
    bonusPercent: (map['bonusPercent'] as num?)?.toInt() ?? 0,
    discountPercent: (map['discountPercent'] as num?)?.toInt() ?? 0,
    highlighted: (map['highlighted'] as bool?) ?? false,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'tokens': tokens,
    'bonusPercent': bonusPercent,
    'discountPercent': discountPercent,
    'highlighted': highlighted,
  };

  int get bonusTokens => (tokens * bonusPercent / 100).round();
  int get totalTokens => tokens + bonusTokens;
  double fullPriceFor(double tokenPrice) => tokens * tokenPrice;
  double priceFor(double tokenPrice) =>
      fullPriceFor(tokenPrice) * (100 - discountPercent) / 100;

  List<String> advantagesFor(double tokenPrice) => [
    '$tokens jetons du projet',
    if (bonusTokens > 0) '+$bonusTokens jetons offerts (+$bonusPercent %)',
    if (discountPercent > 0)
      '-$discountPercent % sur le prix : '
          '${(fullPriceFor(tokenPrice) - priceFor(tokenPrice)).toStringAsFixed(0)} € économisés',
  ];

  /// Packs insérés dans SQLite au premier lancement.
  static const defaults = [
    TokenPack(
      name: 'Découverte',
      tokens: 5,
      bonusPercent: 0,
      discountPercent: 0,
    ),
    TokenPack(
      name: 'Supporter',
      tokens: 20,
      bonusPercent: 5,
      discountPercent: 0,
    ),
    TokenPack(
      name: 'Premium',
      tokens: 50,
      bonusPercent: 10,
      discountPercent: 5,
      highlighted: true,
    ),
    TokenPack(
      name: 'Fondateur',
      tokens: 100,
      bonusPercent: 20,
      discountPercent: 10,
    ),
  ];

  /// Lit les packs enregistrés dans SQLite, triés du plus petit au plus grand.
  static List<TokenPack> sortedFromRows(List<Map<String, Object?>> rows) =>
      rows.map(TokenPack.fromMap).toList()
        ..sort((a, b) => a.tokens.compareTo(b.tokens));
}
