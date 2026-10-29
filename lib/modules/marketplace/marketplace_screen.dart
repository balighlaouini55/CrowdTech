import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import '../../shared/database_error_view.dart';
import '../../shared/data_record_details_page.dart';
import '../../shared/data_record_list_page.dart';
import 'marketplace_cart_page.dart';
import 'marketplace_catalog.dart';
import 'marketplace_management_page.dart';
import 'marketplace_product_form_page.dart';
import 'marketplace_seller_page.dart';

class MarketplaceScreen extends StatefulWidget {
  final String accountKey;
  const MarketplaceScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final Map<String, int> cart = {};
  final Map<String, int> cartRecordIds = {};
  String query = '';
  bool loading = true;
  String? loadError;

  final products = <ProductItem>[];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final rows = await CrowdTechDatabase.loadSeededItems(
        'products',
        marketplaceSampleProducts.map((product) => product.toMap()).toList(),
      );
      final savedCart = await CrowdTechDatabase.getItems('cart');
      if (!mounted) return;
      setState(() {
        products
          ..clear()
          ..addAll(rows.map(ProductItem.fromMap));
        cart.clear();
        cartRecordIds.clear();
        for (final item in savedCart) {
          final name = item['productName']! as String;
          cart[name] = item['quantity']! as int;
          cartRecordIds[name] = item['id']! as int;
        }
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger les produits : $error';
      });
    }
  }

  Future<void> addProduct() async {
    final values = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(builder: (_) => const MarketplaceProductFormPage()),
    );
    if (!mounted || values == null) return;
    final product = ProductItem.fromMap({...values, 'rating': null});
    try {
      final id = await CrowdTechDatabase.insertItem('products', {
        ...product.toMap(),
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() => products.insert(0, product.copyWithId(id)));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produit enregistré dans la base locale.')),
    );
  }

  Future<void> addToCart(ProductItem product) async {
    final nextQuantity = (cart[product.name] ?? 0) + 1;
    try {
      final rowId = cartRecordIds[product.name];
      if (rowId == null) {
        final id = await CrowdTechDatabase.insertItem('cart', {
          'productId': product.id!,
          'productName': product.name,
          'quantity': nextQuantity,
        });
        if (!mounted) return;
        setState(() {
          cart[product.name] = nextQuantity;
          cartRecordIds[product.name] = id;
        });
      } else {
        final updated = await CrowdTechDatabase.updateItem('cart', rowId, {
          'productId': product.id!,
          'productName': product.name,
          'quantity': nextQuantity,
        });
        if (updated != 1) {
          throw Exception('Le panier n’a pas pu être mis à jour.');
        }
        if (!mounted) return;
        setState(() => cart[product.name] = nextQuantity);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} ajouté au panier.')),
    );
  }

  void openCart() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BasketPage(accountKey: widget.accountKey),
      ),
    ).then((_) => loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un produit',
            onPressed: addProduct,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Ouvrir le panier',
            onPressed: openCart,
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text(
                '${cart.values.fold<int>(0, (sum, count) => sum + count)}',
              ),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Autres pages marketplace',
            onSelected: (value) => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => switch (value) {
                  'mine' => const MarketplaceManagementPage(),
                  'orders' => DataRecordListPage(
                    title: 'Suivi des commandes',
                    collection: 'orders',
                    emptyMessage: 'Aucune commande à suivre.',
                    ownedOnly: true,
                    accountKey: widget.accountKey,
                  ),
                  'purchases' => DataRecordListPage(
                    title: 'Historique des achats',
                    collection: 'orders',
                    emptyMessage: 'Aucun achat enregistré.',
                    ownedOnly: true,
                    accountKey: widget.accountKey,
                  ),
                  _ => SellerProfilePage(accountKey: widget.accountKey),
                },
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mine',
                child: Text('Gérer tous les produits'),
              ),
              PopupMenuItem(
                value: 'orders',
                child: Text('Suivi des commandes'),
              ),
              PopupMenuItem(
                value: 'purchases',
                child: Text('Historique des achats'),
              ),
              PopupMenuItem(value: 'seller', child: Text('Profil vendeur')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProducts)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit ou une catégorie',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filtered = products
                          .where(
                            (product) =>
                                product.name.toLowerCase().contains(query) ||
                                product.category.toLowerCase().contains(query),
                          )
                          .toList();
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('Aucun produit trouvé.'),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) => _ProductCard(
                          filtered[index],
                          onAdd: () => addToCart(filtered[index]),
                          onDetails: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DataRecordDetailsPage(
                                title: 'Détails du produit',
                                record: filtered[index].toMap(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onAdd;
  final VoidCallback onDetails;
  const _ProductCard(
    this.product, {
    required this.onAdd,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.devices_rounded,
                size: 42,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.category,
              style: const TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                if (product.rating case final rating?) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  Text(rating.toStringAsFixed(1)),
                ] else
                  const Text('Nouveau · aucun avis'),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${product.price} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  tooltip: 'Ajouter au panier',
                  onPressed: onAdd,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
