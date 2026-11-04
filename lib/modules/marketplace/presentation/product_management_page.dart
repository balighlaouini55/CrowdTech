// Gestion des produits : modifier, supprimer, importer (HTTP).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/presentation/product_form_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/widgets/product_image.dart';
import 'package:crowdtech/shared/pages/record_details_page.dart';
import 'package:crowdtech/shared/utils/api_import.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/management_list_view.dart';
import 'package:crowdtech/shared/widgets/module_avatar.dart';
import 'package:flutter/material.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> products = [];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await MarketplaceRepository.products.all();
      if (!mounted) return;
      setState(() {
        // Chacun gère ses propres éléments ; l'administrateur gère tout.
        products = rows.where(Permissions.canManage).toList().reversed.toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les produits : $exception';
        loading = false;
      });
    }
  }

  Future<void> editProduct(Map<String, Object?> product) async {
    final id = product['id'];
    if (id is! int) return;
    final changes = await Navigator.push<Map<String, Object?>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(initialValues: product),
      ),
    );
    if (!mounted || changes == null) return;
    try {
      final rows = await MarketplaceRepository.products.update(
        id,
        {...product, ...changes}..remove('id'),
      );
      if (rows != 1) throw Exception('Ce produit est introuvable.');
      await loadProducts();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier le produit : $exception');
    }
  }

  Future<void> deleteProduct(Map<String, Object?> product) async {
    final id = product['id'];
    if (id is! int) return;
    final title = product['name']?.toString() ?? 'ce produit';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: Text('Voulez-vous supprimer « $title » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      final rows = await MarketplaceRepository.products.remove(id);
      if (rows != 1) throw Exception('Ce produit est introuvable.');
      await loadProducts();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de supprimer le produit : $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des produits'),
        actions: [
          if (Permissions.isAdmin)
            IconButton(
              onPressed: () => runApiImport(
                context,
                run: () async => MarketplaceRepository.products.import(
                  await CrowdTechApi.fetchProducts(),
                  uniqueKey: 'name',
                ),
                reload: loadProducts,
                successLabel: 'produit(s) importé(s) depuis DummyJSON',
              ),
              tooltip: 'Importer depuis Internet',
              icon: const Icon(Icons.cloud_download_rounded),
            ),
          IconButton(
            onPressed: loadProducts,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const LoadingSkeleton()
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadProducts,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : products.isEmpty
          ? const EmptyState(
              palette: ModulePalette.store,
              icon: Icons.inventory_2_outlined,
              message: 'Aucun produit enregistré.',
            )
          : ManagementListView(
              records: products,
              noun: 'produit',
              searchKeys: const ['name', 'category', 'brand'],
              itemBuilder: (context, product) {
                final title = product['name']?.toString() ?? 'Produit';
                final category = product['category']?.toString() ?? '';
                final price = (product['price'] as num?)?.toDouble() ?? 0;
                final stock = product['stock'] as num?;
                return Card(
                  child: ListTile(
                    leading: const ModuleAvatar(
                      Icons.store_rounded,
                      palette: ModulePalette.store,
                    ),
                    title: Text(title),
                    subtitle: Text(
                      [
                        category,
                        ?product['brand']?.toString(),
                        formatMoney(price),
                        if (stock != null)
                          stock == 0 ? 'rupture' : 'stock $stock',
                      ].join(' • '),
                    ),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RecordDetailsPage(
                          title: title,
                          record: product,
                          banner: ProductImage(
                            category: category,
                            imageUrl: product['imageUrl'] as String?,
                            imageData: product['imageData'] as String?,
                            iconSize: 80,
                          ),
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editProduct(product);
                        if (action == 'delete') deleteProduct(product);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
