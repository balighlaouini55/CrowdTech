// Profil vendeur : réputation (score, niveau, avis) et produits publiés.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/marketplace/domain/seller_reputation.dart';
import 'package:crowdtech/shared/pages/record_list_page.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/star_rating.dart';
import 'package:flutter/material.dart';

class SellerProfilePage extends StatefulWidget {
  /// Compte connecté.
  final String accountKey;

  /// Vendeur affiché (par défaut le compte connecté).
  final String? sellerKey;
  const SellerProfilePage({
    required this.accountKey,
    this.sellerKey,
    super.key,
  });

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  SellerReputation? reputation;
  List<Map<String, Object?>> reviews = [];

  String get sellerKey => widget.sellerKey ?? widget.accountKey;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final loaded = await SellerReputationService.load(sellerKey);
    final rows = await SellerReputationService.reviewsOf(sellerKey);
    if (!mounted) return;
    setState(() {
      reputation = loaded;
      reviews = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rep = reputation;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil vendeur')),
      body: rep == null
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: ModulePalette.store.panel,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: ModulePalette.store.start.withValues(alpha: 0.3),
                    ),
                    boxShadow: softShadow,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.surface,
                        child: Text(
                          rep.emoji,
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sellerKey.split('@').first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        rep.level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Metric('${rep.score}/100', 'réputation'),
                          _Metric(
                            rep.reviewCount == 0
                                ? '—'
                                : rep.averageStars.toStringAsFixed(1),
                            '${rep.reviewCount} avis',
                          ),
                          _Metric(
                            '${(rep.completionRate * 100).round()} %',
                            'commandes réussies',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Score = 70 % note des acheteurs (moyenne pondérée, '
                      'prudente quand il y a peu d’avis) + 30 % commandes '
                      'menées à bien (${rep.completedOrders} terminée(s), '
                      '${rep.problemOrders} litige(s) ou annulation(s)).',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RecordListPage(
                        title: 'Catalogue du vendeur',
                        collection: 'products',
                        emptyMessage: 'Aucun produit publié.',
                        ownedOnly: true,
                        accountKey: sellerKey,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Voir les produits publiés'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Avis des acheteurs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (reviews.isEmpty)
                  const Text(
                    'Pas encore d’avis : ils arrivent après les commandes '
                    'terminées.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                for (final review in reviews)
                  Card(
                    child: ListTile(
                      title: Align(
                        alignment: Alignment.centerLeft,
                        child: StarRating(
                          (review['stars'] as num?)?.toDouble() ?? 0,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if ((review['comment'] ?? '').toString().isNotEmpty)
                            review['comment'].toString(),
                          '${review['ownerKey'].toString().split('@').first} · '
                              '${formatDate(review['createdAt']?.toString())}',
                        ].join('\n'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
