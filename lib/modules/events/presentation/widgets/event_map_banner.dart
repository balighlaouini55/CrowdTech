// Carte du lieu d'un événement (OpenStreetMap). Si les coordonnées ne sont
// pas encore connues, le lieu est géocodé à la demande avec Nominatim et
// enregistré dans SQLite.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EventMapBanner extends StatefulWidget {
  final Map<String, Object?> event;
  const EventMapBanner({required this.event, super.key});

  @override
  State<EventMapBanner> createState() => _EventMapBannerState();
}

class _EventMapBannerState extends State<EventMapBanner> {
  double? latitude;
  double? longitude;
  bool searching = false;
  String? error;

  @override
  void initState() {
    super.initState();
    latitude = (widget.event['latitude'] as num?)?.toDouble();
    longitude = (widget.event['longitude'] as num?)?.toDouble();
  }

  Future<void> locate() async {
    setState(() {
      searching = true;
      error = null;
    });
    final venue = widget.event['venue']?.toString() ?? '';
    final city = widget.event['city']?.toString() ?? '';
    try {
      final place =
          (venue.isEmpty
              ? null
              : await CrowdTechApi.geocodePlace('$venue, $city')) ??
          await CrowdTechApi.geocodeCity(city);
      final lat = place?['latitude'] as double?;
      final lon = place?['longitude'] as double?;
      // L'écran a pu être fermé pendant la recherche.
      if (!mounted) return;
      if (lat == null || lon == null) {
        setState(() {
          searching = false;
          error = 'Lieu introuvable sur OpenStreetMap.';
        });
        return;
      }
      // Coordonnées enregistrées pour les prochaines ouvertures.
      final id = widget.event['id'];
      if (id is int) {
        final current = await EventsRepository.events.byId(id);
        if (current != null) {
          await EventsRepository.events.update(
            id,
            {
              ...current,
              'latitude': lat,
              'longitude': lon,
              if (place?['country'] case final String country
                  when country.isNotEmpty)
                'country': country,
            }..remove('id'),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        latitude = lat;
        longitude = lon;
        searching = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        searching = false;
        error = 'Carte indisponible hors ligne.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lon = longitude;
    if (lat != null && lon != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          OsmMiniMap(latitude: lat, longitude: lon, height: 240),
          Positioned(
            left: 12,
            top: 12,
            child: ActionChip(
              avatar: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Copier le lien de la carte'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: CrowdTechApi.osmLink(lat, lon)),
                );
                if (!context.mounted) return;
                context.showMessage('Lien OpenStreetMap copié.');
              },
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ModulePalette.events.gradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 54, color: Colors.white),
            const SizedBox(height: 10),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            FilledButton.tonalIcon(
              onPressed: searching ? null : locate,
              icon: searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded),
              label: const Text('Voir sur la carte'),
            ),
          ],
        ),
      ),
    );
  }
}
