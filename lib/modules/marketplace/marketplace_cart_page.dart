import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import 'marketplace_catalog.dart';
import 'marketplace_checkout_page.dart';
//hedha marketplace mte3i
class BasketPage extends StatefulWidget {
  final String accountKey;
  const BasketPage({required this.accountKey, super.key});

  @override
  State<BasketPage> createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
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
        CrowdTechDatabase.loadSeededItems(
          'products',
          marketplaceSampleProducts.map((product) => product.toMap()).toList(),
        ),
        CrowdTechDatabase.getItems('cart'),
      ]);
      if (!mounted) return;
      setState(() {
        products = values[0];
        cartItems = values[1];
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
    try {
      if (quantity <= 0) {
        await CrowdTechDatabase.deleteItem('cart', id);
      } else {
        final rows = await CrowdTechDatabase.updateItem(
          'cart',
          id,
          {...item, 'quantity': quantity}..remove('id'),
        );
        if (rows != 1) throw Exception('Article du panier introuvable.');
      }
      await load();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier le panier : $exception'),
        ),
      );
    }
  }

  Future<void> beginCheckout() async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProductCheckoutPage(accountKey: widget.accountKey),
      ),
    );
    if (completed == true && mounted) {
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande enregistrée. Paiement réel non activé.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = cartItems.fold<int>(
      0,
      (sum, item) => sum + (item['quantity']! as int),
    );
    return Scaffold(
      appBar: AppBar(title: Text('Votre panier ($count)')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : cartItems.isEmpty
          ? const Center(child: Text('Votre panier est vide.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in cartItems)
                  Builder(
                    builder: (context) {
                      final product = productFor(item);
                      final quantity = item['quantity']! as int;
                      return Card(
                        child: ListTile(
                          title: Text(product?.name ?? 'Produit indisponible'),
                          subtitle: Text(
                            '$quantity × ${(product?.price ?? 0).toStringAsFixed(2)} €',
                          ),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Retirer un exemplaire',
                                onPressed: () => changeQuantity(item, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$quantity'),
                              IconButton(
                                tooltip: 'Ajouter un exemplaire',
                                onPressed: () => changeQuantity(item, 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total : ${total.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: beginCheckout,
                  child: const Text('Confirmer la commande'),
                ),
              ],
            ),
    );
  }
}
