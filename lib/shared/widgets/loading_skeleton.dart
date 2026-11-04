// Écran de chargement « squelette » : la forme des cartes s'affiche et
// scintille doucement pendant la lecture de la base.

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(controller),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: AppSpacing.xl),
            decoration: cardDecoration(),
          ),
          for (var index = 0; index < 3; index++)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: cardDecoration(radius: AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(90, 20),
                  const SizedBox(height: 14),
                  bar(220, 14),
                  const SizedBox(height: 10),
                  bar(double.infinity, 10),
                  const SizedBox(height: 8),
                  bar(160, 10),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
