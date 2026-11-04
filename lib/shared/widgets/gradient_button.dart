// Bouton principal en dégradé.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

/// Bouton principal en dégradé.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final ModulePalette palette;
  const GradientButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.palette = ModulePalette.funding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = FilledButton.styleFrom(
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledForegroundColor: AppColors.muted,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? palette.gradient : null,
        color: enabled ? null : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.start.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}
