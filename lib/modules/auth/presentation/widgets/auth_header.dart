// En-tête des pages Connexion et Inscription : icône, titre et sous-titre
// sur une carte sombre au halo iris.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Ancienne mascotte, gardée pour compatibilité (non affichée).
  final String emoji;
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.emoji = '👋',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(
        borderColor: AppColors.primary.withValues(alpha: 0.3),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: ModulePalette.funding.glow),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              ModuleIcon(icon: icon, palette: ModulePalette.funding, size: 50),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title.copyWith(fontSize: 21)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
