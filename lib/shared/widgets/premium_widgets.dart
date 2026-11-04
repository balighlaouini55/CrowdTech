// Composants du système de design : carte de surface, titre de section,
// indicateur chiffré, raccourci et ligne de transaction. Utilisés par le
// tableau de bord et les écrans financiers.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';

/// Carte de surface : fond sombre, bordure fine, coins arrondis. Avec
/// [onTap], elle s'enfonce légèrement au toucher.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? background;
  final EdgeInsetsGeometry margin;
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.background,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.md),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(radius: AppRadius.lg, gradient: background),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : PressableScale(child: card);
  }
}

/// Titre de section avec action facultative (« Tout voir »).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {this.actionLabel, this.onAction, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 0, AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.subtitle)),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Indicateur chiffré : icône teintée, valeur et libellé.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: cardDecoration(radius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.figure),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Raccourci : icône dans un carré teinté et libellé dessous.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne d'opération : pastille, titre, détail et montant à droite.
class TransactionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color color;
  final VoidCallback? onTap;
  const TransactionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.color = AppColors.primary,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(amount, style: AppText.figure.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Courbe compacte (évolution d'un portefeuille), dessinée sur l'appareil :
/// pas besoin d'Internet, avec un dégradé sous la ligne. Elle se dessine
/// de gauche à droite à l'apparition.
class SparklineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const SparklineChart({
    required this.values,
    this.color = AppColors.success,
    this.height = 64,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparklinePainter(values, color, progress),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress;
  const _SparklinePainter(this.values, this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final span = high - low == 0 ? 1 : high - low;
    Offset pointAt(int index) => Offset(
      size.width * index / (values.length - 1),
      size.height - 4 - (values[index] - low) / span * (size.height - 8),
    );
    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final previous = pointAt(index - 1);
      final current = pointAt(index);
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.color != color;
}
