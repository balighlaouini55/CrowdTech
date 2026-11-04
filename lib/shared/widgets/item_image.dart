// Image d'un élément (produit, projet, actualité, événement…) :
// photo de l'appareil (base64), sinon lien internet, sinon une vignette en
// dégradé avec une icône.

import 'dart:convert';

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class ItemImage extends StatelessWidget {
  final String? imageUrl;
  final String? imageData;
  final IconData icon;
  final List<Color> colors;
  final double iconSize;

  /// cover : la photo remplit la zone ; contain : la photo entière est visible.
  final BoxFit fit;

  const ItemImage({
    required this.icon,
    required this.colors,
    this.imageUrl,
    this.imageData,
    this.iconSize = 40,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// true si une photo (appareil ou lien) est renseignée.
  static bool hasPhoto(String? imageUrl, String? imageData) =>
      (imageData?.isNotEmpty ?? false) || (imageUrl?.isNotEmpty ?? false);

  /// Vignette sans photo : dégradé, bulles douces, étincelles et icône
  /// dans une pastille.
  Widget fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final small = !side.isFinite || side < 90;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!small) ...[
                Positioned(
                  right: -side * 0.18,
                  top: -side * 0.22,
                  child: SoftBubble(side * 0.7, 0.16),
                ),
                Positioned(
                  left: -side * 0.12,
                  bottom: -side * 0.2,
                  child: SoftBubble(side * 0.5, 0.12),
                ),
                Positioned(
                  left: side * 0.18,
                  top: side * 0.16,
                  child: const Sparkle(7),
                ),
                Positioned(
                  right: side * 0.22,
                  bottom: side * 0.18,
                  child: const Sparkle(5),
                ),
              ],
              Container(
                padding: EdgeInsets.all(small ? 0 : iconSize * 0.45),
                decoration: small
                    ? null
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                child: Icon(icon, size: iconSize, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = imageData;
    final url = imageUrl;
    final Widget image;
    if (data != null && data.isNotEmpty) {
      image = Image.memory(
        base64Decode(data),
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback(),
      );
    } else {
      image = fallback();
    }
    return ColoredBox(
      color: AppColors.surfaceRaised,
      child: SizedBox.expand(child: image),
    );
  }
}
