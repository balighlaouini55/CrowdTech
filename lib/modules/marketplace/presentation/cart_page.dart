// Panier : quantités (limitées par le stock) et total.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/data/sample_products.dart';
import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/modules/marketplace/presentation/checkout_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_image.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/gradient_button.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

class CartPage extends StatefulWidget {
  final String accountKey;
  const CartPage({required this.accountKey, super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> products = [];
  List<Map<String, Object?>> cartItems = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        MarketplaceRepository.products.seeded(
          sampleProducts.map((product) => product.toMap()).toList(),
        ),
        MarketplaceRepository.cart.all(),
      ]);
      if (!mounted) return;
      setState(() {
        products = values[0];
        cartItems = values[1]
            .where((item) => item['ownerKey'] == widget.accountKey)
            .toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger le panier : $exception';
        loading = false;
      });
    }
  }

  ProductItem? productFor(Map<String, Object?> cartItem) {
    final id = cartItem['productId'];
    for (final row in products) {
      if (row['id'] == id) return ProductItem.fromMap(row);
    }
    return null;
  }

  double get total => cartItems.fold<double>(0, (sum, item) {
    final product = productFor(item);
    if (product == null) return sum;
    return sum + product.price * (item['quantity']! as int);
  });

  Future<void> changeQuantity(Map<String, Object?> item, int change) async {
    final id = item['id']! as int;
    final quantity = (item['quantity']! as int) + change;
    final stock = productFor(item)?.stock;
    if (change > 0 && stock != null && quantity > stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Stock insuffisant : $stock exemplaire(s) disponible(s).',
            ),
          ),
        );
      return;
    }
    try {
      if (quantity <= 0) {
        await MarketplaceRepository.cart.remove(id);
      } else {
        final rows = await MarketplaceRepository.cart.update(
          id,
          {...item, 'quantity': quantity}..remove('id'),
        );
        if (rows != 1) throw Exception('Article du panier introuvable.');
      }
      await load();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier le panier : $exception');
    }
  }

  Future<void> beginCheckout() async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CheckoutPage(accountKey: widget.accountKey),
      ),
    );
    if (completed == true && mounted) {
      await load();
      if (!mounted) return;
      context.showMessage(
        'Commande enregistrée 🎉 Merci ! (paiement réel non activé)',
      );
    }
  }

  Widget _emptyCart() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyState(
            icon: Icons.shopping_cart_outlined,
            message: 'Votre panier est vide.',
            palette: ModulePalette.store,
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: ModulePalette.store.start,
            ),
            icon: const Icon(Icons.storefront_rounded),
            label: const Text('Découvrir la boutique'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final count = cartItems.fold<int>(
      0,
      (sum, item) => sum + (item['quantity']! as int),
    );
    return Scaffold(
      appBar: AppBar(title: Text('Votre panier ($count)')),
      body: loading
          ? const LoadingSkeleton()
          : error != null
          ? DatabaseErrorView(message: error!, onRetry: load)
          : cartItems.isEmpty
          ? _emptyCart()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in cartItems)
                  Builder(
                    builder: (context) {
                      final product = productFor(item);
                      final quantity = item['quantity']! as int;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: ProductImage(
                                    category: product?.category ?? '',
                                    imageUrl: product?.imageUrl,
                                    imageData: product?.imageData,
                                    iconSize: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product?.name ?? 'Produit indisponible',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$quantity × ${formatMoney(product?.price ?? 0)}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _QuantityStepper(
                                quantity: quantity,
                                onRemove: () => changeQuantity(item, -1),
                                onAdd: () => changeQuantity(item, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: softShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Livraison',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const Spacer(),
                          Text(
                            'Offerte 🎁',
                            style: TextStyle(
                              color: ModulePalette.store.start,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatMoney(total),
                            style: TextStyle(
                              color: ModulePalette.store.start,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        onPressed: beginCheckout,
                        palette: ModulePalette.store,
                        icon: Icons.shopping_bag_rounded,
                        label: 'Confirmer la commande',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Sélecteur de quantité en forme de pastille : − quantité +.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  const _QuantityStepper({
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final color = ModulePalette.store.start;
    return Container(
      decoration: BoxDecoration(
        color: ModulePalette.store.soft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: quantity == 1
                ? 'Retirer du panier'
                : 'Retirer un exemplaire',
            visualDensity: VisualDensity.compact,
            color: color,
            onPressed: onRemove,
            icon: Icon(
              quantity == 1
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
              size: 20,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Ajouter un exemplaire',
            visualDensity: VisualDensity.compact,
            color: color,
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
