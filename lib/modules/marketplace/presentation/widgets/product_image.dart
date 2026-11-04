// Photo d'un produit : icône et couleurs selon la catégorie (voir ItemImage).

import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String category;
  final String? imageUrl;
  final String? imageData;
  final double iconSize;

  const ProductImage({
    required this.category,
    this.imageUrl,
    this.imageData,
    this.iconSize = 40,
    super.key,
  });

  static IconData iconFor(String category) => switch (category.toLowerCase()) {
    'portable' || 'laptop' => Icons.laptop_mac_rounded,
    'smartphone' => Icons.smartphone_rounded,
    'tablette' => Icons.tablet_mac_rounded,
    'écran' => Icons.monitor_rounded,
    'drone' => Icons.flight_rounded,
    'audio' => Icons.headphones_rounded,
    'montre' => Icons.watch_rounded,
    'accessoire' => Icons.keyboard_rounded,
    _ => Icons.devices_rounded,
  };

  static List<Color> colorsFor(String category) =>
      switch (category.toLowerCase()) {
        'portable' || 'laptop' => const [Color(0xFF818CF8), Color(0xFFC084FC)],
        'smartphone' => const [Color(0xFFF472B6), Color(0xFFFB923C)],
        'tablette' => const [Color(0xFF60A5FA), Color(0xFF22D3EE)],
        'écran' => const [Color(0xFF38BDF8), Color(0xFF34D399)],
        'drone' => const [Color(0xFFFBBF24), Color(0xFFF97316)],
        'audio' => const [Color(0xFFA78BFA), Color(0xFF6366F1)],
        'montre' => const [Color(0xFFF59E0B), Color(0xFFEC4899)],
        'accessoire' => const [Color(0xFF2DD4BF), Color(0xFF60A5FA)],
        _ => const [Color(0xFFA78BFA), Color(0xFFF472B6)],
      };

  @override
  Widget build(BuildContext context) {
    return ItemImage(
      imageUrl: imageUrl,
      imageData: imageData,
      icon: iconFor(category),
      colors: colorsFor(category),
      iconSize: iconSize,
      // Les photos de produits sont détourées : on les montre en entier.
      fit: BoxFit.contain,
    );
  }
}
