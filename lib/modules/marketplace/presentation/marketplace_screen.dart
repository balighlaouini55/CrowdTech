// Écran Marketplace : catalogue, recherche et ajout au panier.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/data/sample_products.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';
import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/modules/marketplace/domain/product_search.dart';
import 'package:crowdtech/modules/marketplace/domain/seller_reputation.dart';
import 'package:crowdtech/modules/marketplace/presentation/cart_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/orders_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/product_form_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/product_management_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/seller_profile_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_card.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_filter_sheet.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_image.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/pages/record_list_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/reload_on_sync.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class MarketplaceScreen extends StatefulWidget {
  final String accountKey;
  const MarketplaceScreen({this.accountKey = 'demo@crowdtech.app', super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with ReloadOnSync<MarketplaceScreen> {
  @override
  void reloadAfterSync() => loadProducts();

  // Panier : identifiant du produit → quantité (et → ligne SQLite).
  final Map<int, int> cart = {};
  final Map<int, int> cartRecordIds = {};
  String query = '';
  bool loading = true;
  String? loadError;

  final products = <ProductItem>[];

  /// Critères de recherche multi-critères (prix, état, marque…).
  ProductFilter filter = const ProductFilter();

  /// Score de réputation de chaque vendeur.
  Map<String, int> sellerScores = {};

  List<ProductItem> get filteredProducts => ProductSearch.apply(
    products,
    filter.copyWith(query: query),
    sellerScores: sellerScores,
  );

  Future<void> openFilters() async {
    final result = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFilterSheet(products: products, initial: filter),
    );
    if (result != null && mounted) setState(() => filter = result);
  }

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
      final rows = await MarketplaceRepository.products.seeded(
        sampleProducts.map((product) => product.toMap()).toList(),
      );
      // Chaque utilisateur a son propre panier.
      final savedCart = await MarketplaceRepository.cart.ownedBy(
        widget.accountKey,
      );
      final reviews = await MarketplaceRepository.sellerReviews.all();
      final orders = await MarketplaceRepository.orders.all();
      if (!mounted) return;
      setState(() {
        products
          ..clear()
          ..addAll(rows.map(ProductItem.fromMap));
        sellerScores = {
          for (final seller in {
            for (final product in products) ?product.ownerKey,
          })
            seller: SellerReputationService.compute(
              seller,
              reviews,
              orders,
            ).score,
        };
        cart.clear();
        cartRecordIds.clear();
        for (final item in savedCart) {
          final productId = item['productId'];
          if (productId is! int) continue;
          cart[productId] = item['quantity']! as int;
          cartRecordIds[productId] = item['id']! as int;
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
      MaterialPageRoute(builder: (_) => const ProductFormPage()),
    );
    if (!mounted || values == null) return;
    final product = ProductItem.fromMap({
      ...values,
      'rating': null,
      'ownerKey': widget.accountKey,
    });
    try {
      final id = await MarketplaceRepository.products.add({
        ...product.toMap(),
        'ownerKey': widget.accountKey,
      });
      if (!mounted) return;
      setState(() => products.insert(0, product.copyWithId(id)));
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    context.showMessage('Produit enregistré dans la base locale.');
  }

  Future<void> addToCart(ProductItem product) async {
    if (product.ownerKey == widget.accountKey) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'C’est votre produit : vous ne pouvez pas l’acheter vous-même.',
            ),
          ),
        );
      return;
    }
    final nextQuantity = (cart[product.id!] ?? 0) + 1;
    final stock = product.stock;
    if (stock != null && nextQuantity > stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              stock == 0
                  ? '${product.name} est en rupture de stock.'
                  : 'Stock insuffisant : $stock exemplaire(s) disponible(s).',
            ),
          ),
        );
      return;
    }
    try {
      final rowId = cartRecordIds[product.id!];
      if (rowId == null) {
        final id = await MarketplaceRepository.cart.add({
          'productId': product.id!,
          'productName': product.name,
          'quantity': nextQuantity,
          'ownerKey': widget.accountKey,
        });
        if (!mounted) return;
        setState(() {
          cart[product.id!] = nextQuantity;
          cartRecordIds[product.id!] = id;
        });
      } else {
        final updated = await MarketplaceRepository.cart.update(rowId, {
          'productId': product.id!,
          'productName': product.name,
          'quantity': nextQuantity,
          'ownerKey': widget.accountKey,
        });
        if (updated != 1) {
          throw Exception('Le panier n’a pas pu être mis à jour.');
        }
        if (!mounted) return;
        setState(() => cart[product.id!] = nextQuantity);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${product.name} ajouté au panier.')),
      );
  }

  void openCart() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CartPage(accountKey: widget.accountKey),
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
            onSelected: (value) =>
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => switch (value) {
                      'mine' => const ProductManagementPage(),
                      'orders' => OrdersPage(accountKey: widget.accountKey),
                      'purchases' => RecordListPage(
                        title: 'Historique des achats',
                        collection: 'orders',
                        emptyMessage: 'Aucun achat enregistré.',
                        ownedOnly: true,
                        accountKey: widget.accountKey,
                      ),
                      _ => SellerProfilePage(accountKey: widget.accountKey),
                    },
                  ),
                ).then((_) {
                  if (mounted) loadProducts();
                }),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mine',
                child: Text(
                  Permissions.isAdmin
                      ? 'Gérer tous les produits'
                      : 'Gérer mes produits',
                ),
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
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProducts)
          : Column(
              children: [
                // En-tête compact : la grille de produits reste visible.
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(16),
                  clipBehavior: Clip.antiAlias,
                  decoration: cardDecoration(
                    radius: AppRadius.lg,
                    gradient: ModulePalette.store.panel,
                    borderColor: ModulePalette.store.start.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: Row(
                    children: [
                      const ModuleIcon(
                        icon: Icons.storefront_rounded,
                        palette: ModulePalette.store,
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Boutique tech', style: AppText.subtitle),
                            Text(
                              'Le meilleur du matériel, payé sous séquestre.',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        '${OrderEscrow.protectionDays} j de protection',
                        tone: BadgeTone.warning,
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(
                            () => query = value.trim().toLowerCase(),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un produit, une marque, une catégorie',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Filtres et tri',
                        onPressed: openFilters,
                        icon: Badge(
                          isLabelVisible: filter.activeCount > 0,
                          label: Text('${filter.activeCount}'),
                          child: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      StatusBadge(
                        '${products.length} produits',
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        '${products.where((product) => !product.inStock).length} en rupture',
                        tone: BadgeTone.neutral,
                        icon: Icons.remove_shopping_cart_outlined,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filtered = filteredProducts;
                      if (filtered.isEmpty) {
                        return const EmptyState(
                          palette: ModulePalette.store,
                          icon: Icons.search_off_rounded,
                          message: 'Aucun produit trouvé.',
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: 286,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) => ProductCard(
                          filtered[index],
                          onAdd: () => addToCart(filtered[index]),
                          onDetails: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => RecordDetailsPage(
                                title: 'Détails du produit',
                                record: filtered[index].toMap(),
                                banner: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ProductImage(
                                      category: filtered[index].category,
                                      imageUrl: filtered[index].imageUrl,
                                      imageData: filtered[index].imageData,
                                      iconSize: 80,
                                    ),
                                    if (filtered[index].ownerKey
                                        case final seller?)
                                      Positioned(
                                        left: 12,
                                        bottom: 12,
                                        child: Builder(
                                          builder: (context) => ActionChip(
                                            avatar: const Icon(
                                              Icons.storefront_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              'Vendeur · '
                                              '${sellerScores[seller] ?? 0}/100',
                                            ),
                                            onPressed: () =>
                                                Navigator.push<void>(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        SellerProfilePage(
                                                          accountKey:
                                                              widget.accountKey,
                                                          sellerKey: seller,
                                                        ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
