// Marché des jetons : les investisseurs revendent leurs jetons à d'autres
// utilisateurs (la collecte du projet ne change pas).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

/// Ouvre le dialogue de mise en vente de jetons d'un projet.
/// Retourne true si l'annonce a été publiée.
Future<bool> sellTokensDialog(
  BuildContext context, {
  required int projectId,
  required String projectTitle,
  required String accountKey,
}) async {
  final available = await CrowdRules.availableTokens(projectId, accountKey);
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  if (available <= 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Aucun jeton disponible à la vente.')),
    );
    return false;
  }
  final values = await showInputDialog(
    context,
    title: 'Revendre des jetons — $projectTitle',
    confirmLabel: 'Mettre en vente',
    fields: [
      DialogField('Nombre de jetons (max $available)', number: true),
      const DialogField('Prix par jeton (€)', number: true),
    ],
  );
  if (values == null) return false;
  try {
    await CrowdRules.createListing(
      projectId,
      tokens: int.tryParse(values[0].trim()) ?? 0,
      pricePerToken:
          double.tryParse(values[1].trim().replaceAll(',', '.')) ?? 0,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Annonce publiée sur le marché 🏷️')),
    );
    return true;
  } on Exception catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('$error')));
    return false;
  }
}

class TokenMarketPage extends StatefulWidget {
  final String accountKey;
  const TokenMarketPage({required this.accountKey, super.key});

  @override
  State<TokenMarketPage> createState() => _TokenMarketPageState();
}

class _TokenMarketPageState extends State<TokenMarketPage> {
  bool loading = true;
  List<Map<String, Object?>> listings = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await CrowdRules.openListings();
    if (!mounted) return;
    setState(() {
      listings = rows;
      loading = false;
    });
  }

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      await load();
      if (!mounted) return;
      context.showMessage(success);
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  Future<void> buy(Map<String, Object?> listing) async {
    final total =
        (listing['tokens']! as num) * (listing['pricePerToken']! as num);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acheter ces jetons ?'),
        content: Text(
          '${listing['tokens']} jeton(s) de « ${listing['projectTitle']} » '
          'pour ${formatMoney(total)} (paiement simulé).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await run(
      () => CrowdRules.buyListing(listing['id']! as int, widget.accountKey),
      'Jetons ajoutés à votre portefeuille 🎉',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marché des jetons')),
      body: loading
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Revente entre investisseurs',
                  subtitle:
                      'Achetez des jetons mis en vente par d’autres '
                      'investisseurs. Pour vendre les vôtres : Mon '
                      'portefeuille → Revendre.',
                  icon: Icons.storefront_rounded,
                  stats: [('${listings.length}', 'annonces')],
                ),
                if (listings.isEmpty)
                  const EmptyState(
                    icon: Icons.sell_outlined,
                    message: 'Aucune annonce pour le moment.',
                  ),
                for (final listing in listings) _listingCard(listing),
              ],
            ),
    );
  }

  Widget _listingCard(Map<String, Object?> listing) {
    final mine = listing['sellerKey'] == widget.accountKey;
    final tokens = (listing['tokens']! as num).toInt();
    final price = (listing['pricePerToken']! as num).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏷️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${listing['projectTitle']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (mine) const StatusBadge('Mon annonce'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$tokens jeton(s) × ${formatMoney(price)} = '
              '${formatMoney(tokens * price)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Publiée le ${formatDate(listing['createdAt']?.toString())}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: mine
                  ? OutlinedButton.icon(
                      onPressed: () => run(
                        () => CrowdRules.cancelListing(listing['id']! as int),
                        'Annonce retirée.',
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Retirer'),
                    )
                  : FilledButton.icon(
                      onPressed: () => buy(listing),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: const Text('Acheter'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
