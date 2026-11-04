// Estimation de la livraison à la commande : vérification du code postal
// (Zippopotam, ou Nominatim pour la Tunisie) puis distance routière depuis
// l'entrepôt (OSRM) → frais et délai.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/marketplace/data/delivery_api.dart';
import 'package:crowdtech/modules/marketplace/domain/delivery_quote.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/material.dart';

class DeliveryEstimateCard extends StatefulWidget {
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final String? country;
  final double orderTotal;
  final ValueChanged<DeliveryQuote?> onQuote;
  const DeliveryEstimateCard({
    required this.cityController,
    required this.postalCodeController,
    required this.country,
    required this.orderTotal,
    required this.onQuote,
    super.key,
  });

  /// Entrepôt d'où partent les colis.
  static const warehouse = 'Tunis, Tunisie';

  @override
  State<DeliveryEstimateCard> createState() => _DeliveryEstimateCardState();
}

class _DeliveryEstimateCardState extends State<DeliveryEstimateCard> {
  bool loading = false;
  DeliveryQuote? quote;
  String? postalWarning;
  String? error;

  Future<void> estimate() async {
    final city = widget.cityController.text.trim();
    final postal = widget.postalCodeController.text.trim();
    final country = widget.country ?? '';
    if (city.isEmpty) {
      setState(() => error = 'Saisissez d’abord la ville de livraison.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      postalWarning = null;
    });
    try {
      final code = DeliveryApi.countryCodes[country];
      if (postal.isNotEmpty && code != null) {
        final places = await DeliveryApi.placesForPostalCode(code, postal);
        if (places.isEmpty) {
          postalWarning = 'Code postal $postal inconnu en $country.';
        } else if (!PostalCheck.matches(city, places)) {
          postalWarning =
              'Le code postal $postal correspond à « ${places.first} », '
              'pas à « $city ». Vérifiez votre adresse.';
        }
      }
      final from = await CrowdTechApi.geocodePlace(
        DeliveryEstimateCard.warehouse,
      );
      final to = await CrowdTechApi.geocodePlace(
        [city, country].where((part) => part.isNotEmpty).join(', '),
      );
      ({double lat, double lon})? point(Map<String, Object?>? place) {
        final lat = place?['latitude'];
        final lon = place?['longitude'];
        return lat is double && lon is double ? (lat: lat, lon: lon) : null;
      }

      final start = point(from);
      final end = point(to);
      final route = start == null || end == null
          ? null
          : await DeliveryApi.route(start, end);
      quote = route == null
          ? null
          : DeliveryQuote.fromRoute(
              km: route.km,
              hours: route.hours,
              orderTotal: widget.orderTotal,
            );
      if (quote == null) error = 'Itinéraire introuvable vers « $city ».';
    } on ApiException catch (exception) {
      quote = null;
      error = 'Estimation indisponible : $exception';
    }
    widget.onQuote(quote);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final current = quote;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ModulePalette.store.soft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Frais et délai de livraison',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonal(
                onPressed: loading ? null : estimate,
                child: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(current == null ? 'Calculer' : 'Recalculer'),
              ),
            ],
          ),
          if (postalWarning != null) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ $postalWarning',
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.muted)),
          ],
          if (current != null) ...[
            const SizedBox(height: 8),
            Text(
              '${current.km.round()} km depuis notre entrepôt de Tunis · '
              'livraison en ${current.days} jour(s) · '
              '${current.isFree ? 'offerte 🎁' : formatMoney(current.cost)}',
              style: const TextStyle(color: AppColors.ink),
            ),
            if (!current.isFree)
              Text(
                'Livraison offerte dès '
                '${formatMoney(DeliveryQuote.freeFrom)} d’achat.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}
