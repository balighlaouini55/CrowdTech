// API gratuites du module Événements, en plus d'OpenStreetMap / Nominatim :
// - Open-Meteo (prévisions) : météo prévue le jour et dans la ville de
//   l'événement ;
// - Nager.Date : jours fériés d'un pays, pour prévenir l'organisateur.

import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/events/domain/event_planning.dart';

class EventsWebApi {
  EventsWebApi._();

  /// Météo prévue le jour [day] au point (latitude, longitude), ou null si
  /// la date est hors de la période couverte (16 jours à venir).
  static Future<DayForecast?> forecast(
    double latitude,
    double longitude,
    DateTime day,
  ) async {
    if (!EventPlanning.hasForecast(day)) return null;
    final date = day.toIso8601String().split('T').first;
    final json = await CrowdTechApi.getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
        'timezone': 'auto',
        'start_date': date,
        'end_date': date,
      }),
    );
    final daily = json is Map ? json['daily'] : null;
    if (daily is! Map) return null;
    num? first(String key) {
      final values = daily[key];
      return values is List && values.isNotEmpty && values.first is num
          ? values.first as num
          : null;
    }

    final code = first('weather_code');
    if (code == null) return null;
    return DayForecast(
      code: code.toInt(),
      maxTemp: first('temperature_2m_max')?.toDouble(),
      minTemp: first('temperature_2m_min')?.toDouble(),
      rainChance: first('precipitation_probability_max')?.toInt(),
    );
  }

  /// Jours fériés de l'année [year] dans le pays [countryCode] (TN, FR…).
  static Future<List<Holiday>> holidays(int year, String countryCode) async {
    final json = await CrowdTechApi.getJson(
      Uri.https('date.nager.at', '/api/v3/PublicHolidays/$year/$countryCode'),
      allowNotFound: true,
    );
    return [
      if (json is List)
        for (final row in json)
          if (row is Map && DateTime.tryParse('${row['date']}') != null)
            Holiday(
              day: DateTime.parse('${row['date']}'),
              name: '${row['name'] ?? ''}',
              localName: '${row['localName'] ?? ''}',
            ),
    ];
  }
}
