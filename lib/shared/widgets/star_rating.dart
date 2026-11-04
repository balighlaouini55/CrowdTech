// Étoiles : affichage d'une note (avec demi-étoiles) et sélecteur 1 à 5.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

const starColor = Color(0xFFFFB938);

/// Affiche une note de 0 à 5 avec des étoiles pleines, demi et vides.
class StarRating extends StatelessWidget {
  final double value;
  final double size;
  const StarRating(this.value, {this.size = 18, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            value >= star
                ? Icons.star_rounded
                : value >= star - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: value >= star - 0.5 ? starColor : AppColors.borderStrong,
          ),
      ],
    );
  }
}

/// Cinq étoiles à toucher pour choisir une note de 1 à 5.
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const StarPicker({
    required this.value,
    required this.onChanged,
    this.size = 44,
    super.key,
  });

  static const labels = [
    '',
    'Bof',
    'Moyen',
    'Bien',
    'Très bien',
    'Excellent !',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              Semantics(
                button: true,
                label: '$star étoile${star > 1 ? 's' : ''}',
                child: GestureDetector(
                  key: ValueKey('star-$star'),
                  onTap: () => onChanged(star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedScale(
                      scale: star <= value ? 1.1 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        star <= value
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: size,
                        color: star <= value
                            ? starColor
                            : AppColors.borderStrong,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value == 0 ? 'Touchez une étoile' : labels[value],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: value == 0 ? AppColors.muted : AppColors.ink,
          ),
        ),
      ],
    );
  }
}
