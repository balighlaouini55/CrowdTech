// Message d'erreur avec bouton « Réessayer ».

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

class DatabaseErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DatabaseErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Une erreur est survenue', style: AppText.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
