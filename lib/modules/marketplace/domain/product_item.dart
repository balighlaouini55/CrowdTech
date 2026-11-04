// Modèle : un produit de la marketplace (prix, marque, stock, état, photo…).

class ProductItem {
  final int? id;
  final String name;
  final double price;
  final double? rating;
  final String category;
  final String? brand;
  final int? stock;
  final String? condition;
  final String? description;

  /// Vendeur (email du compte qui a publié le produit).
  final String? ownerKey;

  /// Photo du produit : lien internet (imageUrl) ou photo choisie sur
  /// l'appareil, enregistrée en base64 dans SQLite (imageData).
  final String? imageUrl;
  final String? imageData;
  const ProductItem({
    this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.category,
    this.brand,
    this.stock,
    this.condition,
    this.description,
    this.ownerKey,
    this.imageUrl,
    this.imageData,
  });

  factory ProductItem.fromMap(Map<String, Object?> map) => ProductItem(
    id: map['id'] as int?,
    name: map['name']! as String,
    price: (map['price']! as num).toDouble(),
    rating: (map['rating'] as num?)?.toDouble(),
    category: map['category']! as String,
    brand: map['brand'] as String?,
    stock: (map['stock'] as num?)?.toInt(),
    condition: map['condition'] as String?,
    description: map['description'] as String?,
    ownerKey: map['ownerKey'] as String?,
    imageUrl: map['imageUrl'] as String?,
    imageData: map['imageData'] as String?,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'price': price,
    'rating': rating,
    'category': category,
    'brand': ?brand,
    'stock': ?stock,
    'condition': ?condition,
    'description': ?description,
    'ownerKey': ?ownerKey,
    'imageUrl': ?imageUrl,
    'imageData': ?imageData,
  };

  /// Un produit sans stock renseigné est considéré comme disponible.
  bool get inStock => stock == null || stock! > 0;

  ProductItem copyWithId(int value) =>
      ProductItem.fromMap({...toMap(), 'id': value});
}
