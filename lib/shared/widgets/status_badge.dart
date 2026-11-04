// Badge de statut coloré (En stock, Financé, Gratuit…).

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

enum BadgeTone { primary, success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;
  const StatusBadge(
    this.label, {
    this.tone = BadgeTone.primary,
    this.icon,
    super.key,
  });

  (Color, Color) get colors => switch (tone) {
    BadgeTone.primary => (AppColors.primarySoft, AppColors.primaryBright),
    BadgeTone.success => (AppColors.successSoft, AppColors.success),
    BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
    BadgeTone.danger => (AppColors.dangerSoft, AppColors.danger),
    BadgeTone.info => (AppColors.infoSoft, AppColors.info),
    BadgeTone.neutral => (AppColors.surfaceHigh, AppColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
