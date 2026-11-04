// Choix et achat d'un pack de jetons pour un projet.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/modules/funding/presentation/widgets/token_pack_card.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/gradient_button.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class PackPurchasePage extends StatefulWidget {
  final String projectTitle;
  final double tokenPrice;
  final double remainingAmount;

  /// Ce que l'utilisateur peut encore investir (plafond de son profil).
  final double personalAllowance;
  final List<TokenPack> packs;

  const PackPurchasePage({
    required this.projectTitle,
    required this.tokenPrice,
    required this.remainingAmount,
    this.personalAllowance = double.infinity,
    required this.packs,
    super.key,
  });

  @override
  State<PackPurchasePage> createState() => _PackPurchasePageState();
}

class _PackPurchasePageState extends State<PackPurchasePage> {
  TokenPack? selectedPack;

  bool isAvailable(TokenPack pack) =>
      pack.priceFor(widget.tokenPrice) <= widget.remainingAmount &&
      pack.priceFor(widget.tokenPrice) <= widget.personalAllowance;

  void buy() {
    final pack = selectedPack;
    if (pack == null) return;
    Navigator.pop(context, pack);
  }

  @override
  Widget build(BuildContext context) {
    final pack = selectedPack;
    return Scaffold(
      appBar: AppBar(title: Text('Investir dans ${widget.projectTitle}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ScreenHeader(
            title: 'Choisissez un pack de jetons',
            subtitle: 'Plus le pack est grand, plus vous recevez de bonus.',
            icon: Icons.card_giftcard_rounded,
            stats: [
              (formatMoney(widget.tokenPrice), 'prix du jeton'),
              (formatMoney(widget.remainingAmount), 'reste à financer'),
              if (widget.personalAllowance.isFinite)
                (formatMoney(widget.personalAllowance), 'votre plafond'),
            ],
          ),
          if (widget.packs.isEmpty)
            const EmptyState(
              icon: Icons.toll_outlined,
              message: 'Aucun pack disponible pour le moment.',
            ),
          for (final (index, item) in widget.packs.indexed)
            FadeSlideIn(
              index: index,
              child: TokenPackCard(
                pack: item,
                tier: index,
                tokenPrice: widget.tokenPrice,
                selected: identical(item, pack),
                available: isAvailable(item),
                onTap: () => setState(() => selectedPack = item),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: softShadow,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: GradientButton(
              onPressed: pack == null ? null : buy,
              icon: Icons.shopping_bag_rounded,
              label: pack == null
                  ? 'Sélectionnez un pack'
                  : 'Acheter le pack ${pack.name} · '
                        '${pack.priceFor(widget.tokenPrice).toStringAsFixed(0)} €',
            ),
          ),
        ),
      ),
    );
  }
}
