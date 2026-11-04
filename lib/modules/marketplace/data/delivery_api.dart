// API gratuites de la livraison (module Marketplace), en plus de QR Server :
// - OSRM (itinéraires OpenStreetMap) : distance et durée de trajet entre le
//   vendeur et l'acheteur, pour calculer les frais et le délai ;
// - Zippopotam.us : villes d'un code postal (France, Belgique, Suisse,
//   Maroc…). Nominatim prend le relais pour les pays non couverts
//   (Tunisie).

import 'package:crowdtech/core/network/crowdtech_api.dart';

/// Trajet routier : distance (km) et durée (heures).
typedef RoadRoute = ({double km, double hours});

class DeliveryApi {
  DeliveryApi._();

  /// Pays couverts par Zippopotam (codes ISO).
  static const zippopotamCountries = {
    'FR',
    'BE',
    'CH',
    'DE',
    'ES',
    'IT',
    'PT',
    'NL',
    'LU',
    'MA',
    'CA',
    'US',
    'GB',
    'TR',
    'IN',
  };

  /// Pays (nom affiché dans les formulaires) → code ISO.
  static const countryCodes = {
    'Tunisie': 'TN',
    'France': 'FR',
    'Belgique': 'BE',
    'Suisse': 'CH',
    'Maroc': 'MA',
    'Algérie': 'DZ',
    'Allemagne': 'DE',
    'Espagne': 'ES',
    'Italie': 'IT',
    'Canada': 'CA',
    'États-Unis': 'US',
  };

  /// Itinéraire en voiture entre deux points (latitude, longitude).
  static Future<RoadRoute?> route(
    ({double lat, double lon}) from,
    ({double lat, double lon}) to,
  ) async {
    final json = await CrowdTechApi.getJson(
      Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${from.lon},${from.lat};${to.lon},${to.lat}',
        {'overview': 'false'},
      ),
    );
    final routes = json is Map && json['code'] == 'Ok' ? json['routes'] : null;
    if (routes is! List || routes.isEmpty) return null;
    final best = routes.first as Map;
    return (
      km: ((best['distance'] as num?) ?? 0) / 1000,
      hours: ((best['duration'] as num?) ?? 0) / 3600,
    );
  }

  /// Villes (et régions) qui correspondent à un code postal, en minuscules.
  /// Liste vide si le code postal n'existe pas dans ce pays.
  static Future<List<String>> placesForPostalCode(
    String countryCode,
    String postalCode,
  ) async {
    final code = countryCode.toUpperCase();
    if (zippopotamCountries.contains(code)) {
      final json = await CrowdTechApi.getJson(
        Uri.https('api.zippopotam.us', '/${code.toLowerCase()}/$postalCode'),
        allowNotFound: true,
      );
      final places = json is Map ? json['places'] : null;
      return [
        if (places is List)
          for (final place in places)
            if (place is Map) ...[
              '${place['place name'] ?? ''}',
              '${place['state'] ?? ''}',
            ],
      ].where((name) => name.isNotEmpty).toList();
    }
    final json = await CrowdTechApi.getJson(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'postalcode': postalCode,
        'countrycodes': code.toLowerCase(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
        'accept-language': 'fr',
      }),
    );
    return [
      if (json is List)
        for (final place in json)
          if (place is Map && place['address'] is Map)
            for (final key in const [
              'city',
              'town',
              'village',
              'county',
              'state_district',
              'state',
            ])
              if ((place['address'] as Map)[key] case final String name) name,
    ];
  }
}
