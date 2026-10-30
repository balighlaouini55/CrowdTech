import 'package:flutter/material.dart';
//hedga page management marketplace
import '../../data/crowdtech_database.dart';
import '../../shared/data_record_details_page.dart';
import 'marketplace_product_form_page.dart';

class MarketplaceManagementPage extends StatefulWidget {
  const MarketplaceManagementPage({super.key});

  @override
  State<MarketplaceManagementPage> createState() =>
      _MarketplaceManagementPageState();
}

class _MarketplaceManagementPageState extends State<MarketplaceManagementPage> {
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
      final rows = await CrowdTechDatabase.getItems('products');
      if (!mounted) return;
      setState(() {
        products = rows.reversed.toList();
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
        builder: (_) => MarketplaceProductFormPage(initialValues: product),
      ),
    );
    if (!mounted || changes == null) return;
    try {
      final rows = await CrowdTechDatabase.updateItem(
        'products',
        id,
        {...product, ...changes}..remove('id'),
      );
      if (rows != 1) throw Exception('Ce produit est introuvable.');
      await loadProducts();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier le produit : $exception'),
        ),
      );
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
      final rows = await CrowdTechDatabase.deleteItem('products', id);
      if (rows != 1) throw Exception('Ce produit est introuvable.');
      await loadProducts();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de supprimer le produit : $exception'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des produits'),
        actions: [
          IconButton(
            onPressed: loadProducts,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
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
          ? const Center(child: Text('Aucun produit enregistré.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final title = product['name']?.toString() ?? 'Produit';
                final category = product['category']?.toString() ?? '';
                final price = (product['price'] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.store_rounded),
                    ),
                    title: Text(title),
                    subtitle: Text('$category • ${price.toStringAsFixed(2)} €'),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataRecordDetailsPage(
                          title: title,
                          record: product,
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
