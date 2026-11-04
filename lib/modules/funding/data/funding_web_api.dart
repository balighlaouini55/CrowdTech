// API gratuites du module Crowdfunding, en plus d'ExchangeRate-API et de
// QuickChart :
// - Frankfurter (taux de la Banque centrale européenne) : historique des
//   taux de change, pour suivre l'évolution du prix d'un jeton par devise ;
// - Banque mondiale (World Bank API) : inflation annuelle d'un pays, pour
//   calculer le rendement réel d'un investissement.

import 'package:crowdtech/core/network/crowdtech_api.dart';

/// Taux d'un jour.
typedef DailyRate = ({DateTime day, double rate});

/// Inflation annuelle d'un pays (en %).
typedef Inflation = ({String country, int year, double percent});

class FundingWebApi {
  FundingWebApi._();

  /// Devises suivies par la BCE (le dinar tunisien n'en fait pas partie).
  static const historyCurrencies = [
    'USD',
    'GBP',
    'CHF',
    'CAD',
    'JPY',
    'CNY',
    'TRY',
  ];

  /// Taux EUR → [symbol] des [days] derniers jours (jours ouvrés).
  static Future<List<DailyRate>> rateHistory(
    String symbol, {
    int days = 30,
    DateTime? today,
  }) async {
    final end = today ?? DateTime.now();
    final start = end.subtract(Duration(days: days));
    String day(DateTime date) => date.toIso8601String().split('T').first;
    final json = await CrowdTechApi.getJson(
      Uri.https('api.frankfurter.dev', '/v1/${day(start)}..${day(end)}', {
        'base': 'EUR',
        'symbols': symbol,
      }),
    );
    final rates = json is Map ? json['rates'] : null;
    if (rates is! Map) throw const ApiException('Historique indisponible.');
    final history = [
      for (final MapEntry(:key, :value) in rates.entries)
        if (value is Map && value[symbol] is num)
          (
            day: DateTime.parse(key.toString()),
            rate: (value[symbol]! as num).toDouble(),
          ),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return history;
  }

  /// Dernière inflation annuelle connue (indice des prix à la
  /// consommation) du pays [countryCode] (TN, FR…), ou null.
  static Future<Inflation?> inflation(String countryCode) async {
    final json = await CrowdTechApi.getJson(
      Uri.https(
        'api.worldbank.org',
        '/v2/country/$countryCode/indicator/FP.CPI.TOTL.ZG',
        {'format': 'json', 'mrnev': '1'},
      ),
    );
    if (json is! List || json.length < 2 || json[1] is! List) return null;
    final rows = json[1] as List;
    if (rows.isEmpty || rows.first is! Map) return null;
    final row = rows.first as Map;
    final value = row['value'];
    if (value is! num) return null;
    return (
      country: (row['country'] as Map?)?['value']?.toString() ?? countryCode,
      year: int.tryParse('${row['date']}') ?? 0,
      percent: value.toDouble(),
    );
  }
}
