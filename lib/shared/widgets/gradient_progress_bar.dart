// Barre de progression en dégradé qui se remplit avec une animation.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class GradientProgressBar extends StatelessWidget {
  /// Valeur entre 0 et 1.
  final double value;
  final ModulePalette palette;
  final double height;
  const GradientProgressBar({
    required this.value,
    this.palette = ModulePalette.funding,
    this.height = 8,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(height),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: animated,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: palette.gradient,
              borderRadius: BorderRadius.circular(height),
              boxShadow: [
                BoxShadow(
                  color: palette.start.withValues(alpha: 0.28),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
