// En-tête des écrans : carte sombre, halo discret à la couleur du module,
// icône, titre et chiffres clés animés.

import 'dart:math' as math;

import 'package:crowdtech/app/app_theme.dart';
import 'package:flutter/material.dart';

/// En-tête des écrans principaux : icône du module, titre, sous-titre et
/// indicateurs (valeur, libellé).
class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<(String, String)> stats;
  final ModulePalette palette;
  const ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.stats = const [],
    this.palette = ModulePalette.funding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.glow),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModuleIcon(icon: icon, palette: palette),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.title),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppText.caption.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (final (index, (value, label))
                            in stats.indexed) ...[
                          if (index > 0)
                            const VerticalDivider(
                              width: 1,
                              color: AppColors.border,
                            ),
                          Expanded(
                            child: _Stat(value: value, label: label),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icône d'un module dans un carré teinté à bordure lumineuse.
class ModuleIcon extends StatelessWidget {
  final IconData icon;
  final ModulePalette palette;
  final double size;
  const ModuleIcon({
    required this.icon,
    required this.palette,
    this.size = 44,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.start.withValues(alpha: 0.28),
            palette.end.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: palette.start.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: palette.start, size: size * 0.5),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    // Apparition douce : le chiffre monte légèrement en devenant visible.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppText.figure.copyWith(fontSize: 18)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulle translucide (décor des écrans d'accueil sur fond en dégradé).
class SoftBubble extends StatelessWidget {
  final double size;
  final double opacity;
  const SoftBubble(this.size, this.opacity, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Petite étoile à quatre branches (étincelle) dessinée à la main.
class Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const Sparkle(this.size, {this.color = Colors.white, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size * 2),
      painter: _SparklePainter(color.withValues(alpha: 0.85)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  const _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.28;
    final path = Path();
    for (var index = 0; index < 8; index++) {
      final radius = index.isEven ? outer : inner;
      final angle = index * math.pi / 4 - math.pi / 2;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}
