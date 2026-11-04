// Communication HTTP avec les API publiques gratuites (Hacker News, GitHub,
// DummyJSON, Open-Meteo, Nominatim / OpenStreetMap, ExchangeRate-API,
// QuickChart, QR Server). Les API propres à un module sont dans le dossier
// `data/` de ce module et passent par [CrowdTechApi.getJson].

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Communication HTTP avec les API publiques utilisées par les modules.
/// Les résultats sont ensuite enregistrés dans SQLite par les écrans.
class CrowdTechApi {
  CrowdTechApi._();

  static http.Client client = http.Client();
  static const timeout = Duration(seconds: 15);

  static const _headers = {
    'Accept': 'application/json',
    if (!kIsWeb) 'User-Agent': 'CrowdTech-App',
  };

  /// Lit une réponse JSON. Avec [allowNotFound], une réponse 404 donne null
  /// (élément inexistant) au lieu d'une erreur.
  static Future<Object?> getJson(Uri uri, {bool allowNotFound = false}) async {
    final http.Response response;
    try {
      response = await client.get(uri, headers: _headers).timeout(timeout);
    } on Exception catch (error) {
      throw ApiException('Connexion impossible : $error');
    }
    return _decodeJson(response, allowNotFound: allowNotFound);
  }

  /// Envoie un formulaire (application/x-www-form-urlencoded) et lit la
  /// réponse JSON.
  static Future<Object?> postForm(Uri uri, Map<String, String> fields) async {
    final http.Response response;
    try {
      response = await client
          .post(uri, headers: _headers, body: fields)
          .timeout(timeout);
    } on Exception catch (error) {
      throw ApiException('Connexion impossible : $error');
    }
    return _decodeJson(response);
  }

  static Object? _decodeJson(
    http.Response response, {
    bool allowNotFound = false,
  }) {
    if (allowNotFound && response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException('Le serveur a répondu ${response.statusCode}.');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Réponse du serveur invalide.');
    }
  }

  /// Actualités : meilleurs articles tech de Hacker News.
  static Future<List<Map<String, Object?>>> fetchTechNews({
    int limit = 5,
  }) async {
    final ids = await getJson(
      Uri.https('hacker-news.firebaseio.com', '/v0/topstories.json'),
    );
    if (ids is! List) throw const ApiException('Liste d’articles invalide.');
    final stories = await Future.wait(
      ids
          .take(limit)
          .map(
            (id) => getJson(
              Uri.https('hacker-news.firebaseio.com', '/v0/item/$id.json'),
            ),
          ),
    );
    return [
      for (final story in stories)
        if (story is Map && story['title'] is String)
          {
            'title': story['title'],
            'source': 'Hacker News',
            'credibility': (60 + ((story['score'] as num?) ?? 0) ~/ 20)
                .clamp(60, 99)
                .toInt(),
            'tag': 'Web',
            'summary':
                story['url']?.toString() ??
                'Discussion proposée par ${story['by'] ?? 'la communauté'}.',
          },
    ];
  }

  /// Crowdfunding : projets open source populaires sur GitHub.
  static Future<List<Map<String, Object?>>> fetchFundingProjects({
    int limit = 5,
  }) async {
    final json = await getJson(
      Uri.https('api.github.com', '/search/repositories', {
        'q': 'topic:artificial-intelligence stars:>1000',
        'sort': 'updated',
        'per_page': '$limit',
      }),
    );
    final items = json is Map ? json['items'] : null;
    if (items is! List) throw const ApiException('Liste de projets invalide.');
    return [
      for (final repo in items)
        if (repo is Map && repo['name'] is String)
          {
            'title': repo['name'],
            'company':
                (repo['owner'] as Map?)?['login']?.toString() ?? 'GitHub',
            'amountRaised': 0.0,
            'goal': ((((repo['stargazers_count'] as num?) ?? 0) * 2).clamp(
              20000,
              200000,
            )).toDouble(),
            'tokenPrice': 25.0,
            'progress': 0,
            'feature': repo['description']?.toString() ?? 'Projet open source',
          },
    ];
  }

  /// Marketplace : produits tech (ordinateurs et smartphones) de DummyJSON.
  static Future<List<Map<String, Object?>>> fetchProducts({
    int limit = 4,
  }) async {
    const categories = {'laptops': 'Portable', 'smartphones': 'Smartphone'};
    final responses = await Future.wait(
      categories.keys.map(
        (category) => getJson(
          Uri.https('dummyjson.com', '/products/category/$category', {
            'limit': '$limit',
            'select': 'title,price,rating,thumbnail',
          }),
        ),
      ),
    );
    final products = <Map<String, Object?>>[];
    for (final (index, json) in responses.indexed) {
      final items = json is Map ? json['products'] : null;
      if (items is! List) throw const ApiException('Catalogue invalide.');
      for (final product in items) {
        if (product is! Map || product['title'] is! String) continue;
        products.add({
          'name': product['title'],
          'price': ((product['price'] as num?) ?? 0).toDouble(),
          'rating': (product['rating'] as num?)?.toDouble(),
          'category': categories.values.elementAt(index),
          'imageUrl': product['thumbnail']?.toString(),
        });
      }
    }
    return products;
  }

  /// Événements : vérifie qu’une ville existe et renvoie pays et coordonnées.
  /// Nominatim (OpenStreetMap) est interrogé d’abord ; Open-Meteo sert de
  /// secours si Nominatim ne répond pas.
  static Future<Map<String, Object?>?> geocodeCity(String city) async {
    try {
      final place = await geocodePlace(city);
      if (place != null) return place;
    } on ApiException {
      // Nominatim indisponible : on essaie Open-Meteo.
    }
    return _geocodeOpenMeteo(city);
  }

  static Future<Map<String, Object?>?> _geocodeOpenMeteo(String city) async {
    final json = await getJson(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': city,
        'count': '1',
        'language': 'fr',
      }),
    );
    final results = json is Map ? json['results'] : null;
    if (results is! List || results.isEmpty) return null;
    final place = results.first as Map;
    return {
      'country': place['country']?.toString() ?? '',
      'latitude': (place['latitude'] as num?)?.toDouble(),
      'longitude': (place['longitude'] as num?)?.toDouble(),
    };
  }

  /// Nominatim (OpenStreetMap, gratuit) : géocode une adresse ou un lieu
  /// (« Cité des Sciences, Tunis »). Retourne pays, coordonnées et adresse
  /// complète, ou null si rien n'est trouvé.
  static Future<Map<String, Object?>?> geocodePlace(String query) async {
    final json = await getJson(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
        'accept-language': 'fr',
      }),
    );
    if (json is! List || json.isEmpty) return null;
    final place = json.first;
    if (place is! Map) return null;
    final address = place['address'];
    return {
      'country': address is Map ? address['country']?.toString() ?? '' : '',
      'latitude': double.tryParse(place['lat']?.toString() ?? ''),
      'longitude': double.tryParse(place['lon']?.toString() ?? ''),
      'displayName': place['display_name']?.toString() ?? '',
      // Code ISO du pays en majuscules (TN, FR…), pour les jours fériés.
      'countryCode': address is Map
          ? address['country_code']?.toString().toUpperCase() ?? ''
          : '',
    };
  }

  /// ExchangeRate-API (point d'accès libre, sans clé) : taux de change
  /// depuis [base], par exemple {'TND': 3.38, 'USD': 1.08}.
  static Future<Map<String, double>> fetchExchangeRates({
    String base = 'EUR',
  }) async {
    final json = await getJson(
      Uri.https('open.er-api.com', '/v6/latest/$base'),
    );
    final rates = json is Map ? json['rates'] : null;
    if (json is! Map || json['result'] != 'success' || rates is! Map) {
      throw const ApiException('Taux de change indisponibles.');
    }
    return {
      for (final MapEntry(:key, :value) in rates.entries)
        if (value is num) key.toString(): value.toDouble(),
    };
  }

  /// QR Server API (gratuite) : image PNG d'un QR code contenant [data].
  static String qrCodeUrl(String data, {int size = 240}) => Uri.https(
    'api.qrserver.com',
    '/v1/create-qr-code/',
    {'size': '${size}x$size', 'data': data, 'margin': '8'},
  ).toString();

  /// QuickChart API (gratuite) : image PNG d'un graphique Chart.js décrit
  /// par [config].
  static String quickChartUrl(
    Map<String, Object?> config, {
    int width = 500,
    int height = 280,
  }) => Uri.https('quickchart.io', '/chart', {
    'w': '$width',
    'h': '$height',
    'bkg': 'white',
    'devicePixelRatio': '2',
    'c': jsonEncode(config),
  }).toString();

  /// Tuile OpenStreetMap (gratuite) qui contient le point demandé, avec la
  /// position du point dans la tuile (0 à 1).
  static ({String url, double x, double y}) osmTile(
    double latitude,
    double longitude, {
    int zoom = 15,
  }) {
    final n = 1 << zoom;
    final xTile = (longitude + 180) / 360 * n;
    final latRad = latitude * math.pi / 180;
    final yTile =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        n;
    return (
      url:
          'https://tile.openstreetmap.org/$zoom/${xTile.floor()}/${yTile.floor()}.png',
      x: xTile - xTile.floor(),
      y: yTile - yTile.floor(),
    );
  }

  /// Lien vers la carte OpenStreetMap centrée sur un point.
  static String osmLink(double latitude, double longitude) =>
      'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude'
      '#map=16/$latitude/$longitude';
}
