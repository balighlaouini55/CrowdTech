// Carte d'un pack de jetons sur la page d'achat.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class TokenPackCard extends StatelessWidget {
  final TokenPack pack;
  final int tier;
  final double tokenPrice;
  final bool selected;
  final bool available;
  final VoidCallback onTap;
  const TokenPackCard({
    super.key,
    required this.pack,
    required this.tier,
    required this.tokenPrice,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  /// Couleur du pack selon son rang (du plus petit au plus grand).
  static const tierColors = [
    [Color(0xFF2DD4BF), Color(0xFF38BDF8)],
    [Color(0xFF60A5FA), Color(0xFF818CF8)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFFF59E0B), Color(0xFFF97316)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = tierColors[tier % tierColors.length];
    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(selected ? 2.5 : 0),
        decoration: BoxDecoration(
          gradient: selected ? gradient : null,
          borderRadius: BorderRadius.circular(26),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : softShadow,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: available ? onTap : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pack.highlighted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(gradient: gradient),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Le plus populaire',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.toll_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pack ${pack.name}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  'Total reçu : ${pack.totalTokens} jetons',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_off_rounded,
                              key: ValueKey(selected),
                              color: selected ? colors.first : AppColors.muted,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShaderMask(
                            shaderCallback: gradient.createShader,
                            child: Text(
                              '${pack.priceFor(tokenPrice).toStringAsFixed(0)} €',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (pack.discountPercent > 0) ...[
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '${pack.fullPriceFor(tokenPrice).toStringAsFixed(0)} €',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            const Spacer(),
                            StatusBadge(
                              '-${pack.discountPercent} %',
                              tone: BadgeTone.danger,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final perk in pack.advantagesFor(tokenPrice))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: colors.first,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  perk,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!available)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: StatusBadge(
                            'Dépasse le montant restant à financer',
                            tone: BadgeTone.danger,
                            icon: Icons.block_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
