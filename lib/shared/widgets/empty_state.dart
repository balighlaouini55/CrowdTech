// État vide d'une liste : icône dans un anneau teinté et message court.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final ModulePalette palette;

  /// Action facultative proposée sous le message (« Créer un projet »…).
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    required this.icon,
    required this.message,
    this.palette = ModulePalette.funding,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.start.withValues(alpha: 0.10),
                  border: Border.all(
                    color: palette.start.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, size: 32, color: palette.start),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
