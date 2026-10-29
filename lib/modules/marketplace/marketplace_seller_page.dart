import 'package:flutter/material.dart';

import '../../shared/data_record_list_page.dart';

class SellerProfilePage extends StatelessWidget {
  final String accountKey;
  const SellerProfilePage({required this.accountKey, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil vendeur')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.storefront_outlined, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vendeur CrowdTech',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profil de démonstration. Les vendeurs ne sont pas encore reliés à des comptes vérifiés.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          _SellerProductListLink(accountKey: accountKey),
        ],
      ),
    );
  }
}

class _SellerProductListLink extends StatelessWidget {
  final String accountKey;
  const _SellerProductListLink({required this.accountKey});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DataRecordListPage(
            title: 'Catalogue du vendeur',
            collection: 'products',
            emptyMessage: 'Aucun produit publié.',
            ownedOnly: true,
            accountKey: accountKey,
          ),
        ),
      ),
      icon: const Icon(Icons.inventory_2_outlined),
      label: const Text('Voir les produits publiés'),
    );
  }
}
