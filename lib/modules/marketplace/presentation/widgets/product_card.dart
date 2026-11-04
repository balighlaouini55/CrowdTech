// Carte d'un produit dans la grille du catalogue.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_image.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onAdd;
  final VoidCallback onDetails;
  const ProductCard(
    this.product, {
    super.key,
    required this.onAdd,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.stock;
    final (stockLabel, stockTone) = stock == null
        ? ('Disponible', BadgeTone.success)
        : stock == 0
        ? ('Rupture', BadgeTone.danger)
        : stock <= 3
        ? ('Plus que $stock', BadgeTone.warning)
        : ('En stock', BadgeTone.success);
    return FadeSlideIn(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDetails,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: ProductImage(
                      category: product.category,
                      imageUrl: product.imageUrl,
                      imageData: product.imageData,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.brand ?? product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    StatusBadge(stockLabel, tone: stockTone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (product.rating case final rating?) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ] else
                      const Flexible(
                        child: Text(
                          'Nouveau · aucun avis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (product.condition case final condition?
                        when condition != 'Neuf') ...[
                      const Spacer(),
                      Flexible(
                        child: Text(
                          condition,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatMoney(product.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Ajouter au panier',
                      onPressed: product.inStock ? onAdd : null,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: ModulePalette.store.start,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
