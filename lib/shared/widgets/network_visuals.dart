// Images produites par des API gratuites : QR code (QR Server), graphique
// (QuickChart) et carte (tuiles OpenStreetMap). Chaque widget affiche un
// remplacement lisible si l'appareil est hors ligne.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:flutter/material.dart';

/// QR code généré par QR Server API ; le code texte reste lisible dessous.
class QrCodeImage extends StatelessWidget {
  final String data;
  final double size;
  const QrCodeImage(this.data, {this.size = 200, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Image.network(
        CrowdTechApi.qrCodeUrl(data, size: size.round() * 2),
        fit: BoxFit.contain,
        semanticLabel: 'QR code',
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (context, error, stack) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 90, color: AppColors.ink),
            Text(
              'QR hors ligne',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Graphique Chart.js rendu par QuickChart API.
class QuickChartImage extends StatelessWidget {
  final Map<String, Object?> config;
  final double height;

  /// Affiché si le graphique ne peut pas être chargé (hors ligne).
  final Widget? fallback;
  const QuickChartImage({
    required this.config,
    this.height = 220,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.network(
          CrowdTechApi.quickChartUrl(config, height: height.round() + 40),
          fit: BoxFit.contain,
          semanticLabel: 'Graphique',
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (context, error, stack) =>
              fallback ??
              const Center(
                child: Text(
                  'Graphique indisponible hors ligne.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
        ),
      ),
    );
  }
}

/// Mini-carte OpenStreetMap (une tuile) avec un repère sur le lieu.
class OsmMiniMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double height;
  const OsmMiniMap({
    required this.latitude,
    required this.longitude,
    this.height = 180,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tile = CrowdTechApi.osmTile(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // La tuile (256 px) est agrandie pour couvrir la zone, centrée
            // sur le point.
            final side = constraints.maxWidth > height
                ? constraints.maxWidth
                : height;
            final left = constraints.maxWidth / 2 - tile.x * side;
            final top = height / 2 - tile.y * side;
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: ModulePalette.events.soft),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: side,
                  height: side,
                  child: Image.network(
                    tile.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: ModulePalette.store.end,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  right: 6,
                  bottom: 4,
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: AppColors.ink),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
