// Calculateur d'évolution du portefeuille : montant investi cumulé jour par
// jour, et projection de la valeur selon un rendement annuel (simulation ROI).
// Produit aussi la configuration Chart.js envoyée à QuickChart.

import 'dart:math' as math;

import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/shared/utils/formatters.dart';

/// Un point de la courbe du portefeuille.
class PortfolioPoint {
  final DateTime date;
  final double invested;
  final int tokens;
  const PortfolioPoint(this.date, this.invested, this.tokens);
}

class PortfolioAnalytics {
  PortfolioAnalytics._();

  /// Montant investi et jetons cumulés, un point par jour d'opération.
  /// Les investissements remboursés sont ignorés.
  static List<PortfolioPoint> evolution(List<Map<String, Object?>> rows) {
    final dated = [
      for (final row in rows)
        if (CrowdRules.isActive(row))
          if (DateTime.tryParse(row['createdAt']?.toString() ?? '')
              case final date?)
            (date, row),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final points = <PortfolioPoint>[];
    var invested = 0.0;
    var tokens = 0;
    for (final (date, row) in dated) {
      invested += (row['amount'] as num?)?.toDouble() ?? 0;
      tokens += (row['tokens'] as num?)?.toInt() ?? 0;
      final day = DateTime(date.year, date.month, date.day);
      if (points.isNotEmpty && points.last.date == day) {
        points[points.length - 1] = PortfolioPoint(day, invested, tokens);
      } else {
        points.add(PortfolioPoint(day, invested, tokens));
      }
    }
    return points;
  }

  /// Valeur projetée après [years] années à [ratePercent] % par an
  /// (intérêts composés).
  static double projectedValue(double amount, double ratePercent, int years) =>
      amount * math.pow(1 + ratePercent / 100, years);

  /// ROI en pourcentage entre un montant investi et une valeur.
  static double roiPercent(double invested, double value) =>
      invested <= 0 ? 0 : (value - invested) / invested * 100;

  /// Rendement réel annuel (équation de Fisher) : ce que l'investissement
  /// rapporte vraiment une fois l'inflation déduite.
  /// 8 % par an avec 5 % d'inflation → 2,86 % réel (et non 3 %).
  static double realRatePercent(
    double nominalPercent,
    double inflationPercent,
  ) => ((1 + nominalPercent / 100) / (1 + inflationPercent / 100) - 1) * 100;

  /// Valeur projetée en euros d'aujourd'hui (pouvoir d'achat), après
  /// [years] années à [nominalPercent] % avec [inflationPercent] % d'inflation.
  static double realValue(
    double amount,
    double nominalPercent,
    double inflationPercent,
    int years,
  ) => projectedValue(
    amount,
    realRatePercent(nominalPercent, inflationPercent),
    years,
  );

  /// Villes des projets → code pays (Banque mondiale, jours fériés…).
  static const _cityCountries = {
    'tunis': 'TN',
    'sfax': 'TN',
    'sousse': 'TN',
    'monastir': 'TN',
    'bizerte': 'TN',
    'nabeul': 'TN',
    'gabès': 'TN',
    'paris': 'FR',
    'lyon': 'FR',
    'marseille': 'FR',
    'bordeaux': 'FR',
    'lille': 'FR',
    'toulouse': 'FR',
    'nice': 'FR',
    'casablanca': 'MA',
    'rabat': 'MA',
    'alger': 'DZ',
    'bruxelles': 'BE',
    'genève': 'CH',
    'montréal': 'CA',
  };

  /// Code pays d'une ville connue, sinon [fallback].
  static String countryOfCity(String? city, {String fallback = 'TN'}) =>
      _cityCountries[city?.trim().toLowerCase()] ?? fallback;

  /// Variation en % entre le premier et le dernier taux d'un historique.
  static double variationPercent(List<double> rates) =>
      rates.length < 2 || rates.first == 0
      ? 0
      : (rates.last - rates.first) / rates.first * 100;

  /// Configuration Chart.js : prix d'un jeton converti dans une devise,
  /// jour par jour.
  static Map<String, Object?> tokenPriceChart({
    required double tokenPrice,
    required String currency,
    required List<({DateTime day, double rate})> history,
  }) => {
    'type': 'line',
    'data': {
      'labels': [
        for (final point in history)
          '${twoDigits(point.day.day)}/'
              '${twoDigits(point.day.month)}',
      ],
      'datasets': [
        {
          'label': 'Prix du jeton ($currency)',
          'data': [
            for (final point in history)
              double.parse((tokenPrice * point.rate).toStringAsFixed(2)),
          ],
          'borderColor': '#8B7CF6',
          'backgroundColor': 'rgba(139,124,246,0.18)',
          'fill': true,
          'tension': 0.35,
          'pointRadius': 0,
        },
      ],
    },
    'options': {
      'plugins': {
        'legend': {'position': 'bottom'},
      },
    },
  };

  /// Configuration Chart.js : montant investi cumulé (et projection sur
  /// 3 ans avec [ratePercent]).
  static Map<String, Object?> chartConfig(
    List<PortfolioPoint> points, {
    double ratePercent = 8,
  }) {
    String label(DateTime date) =>
        '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}';
    final total = points.isEmpty ? 0.0 : points.last.invested;
    final labels = [
      for (final point in points) label(point.date),
      for (var year = 1; year <= 3; year++) '+$year an',
    ];
    final history = [
      for (final point in points) point.invested.round(),
      for (var year = 1; year <= 3; year++) null,
    ];
    final projection = [
      for (var i = 0; i < points.length - 1; i++) null,
      total.round(),
      for (var year = 1; year <= 3; year++)
        projectedValue(total, ratePercent, year).round(),
    ];
    return {
      'type': 'line',
      'data': {
        'labels': labels,
        'datasets': [
          {
            'label': 'Investi (€)',
            'data': history,
            'borderColor': '#8B7CF6',
            'backgroundColor': 'rgba(139,124,246,0.18)',
            'fill': true,
            'tension': 0.35,
          },
          {
            'label': 'Projection ${ratePercent.toStringAsFixed(0)} %/an',
            'data': projection,
            'borderColor': '#FF8FC0',
            'borderDash': [6, 4],
            'fill': false,
            'tension': 0.35,
          },
        ],
      },
      'options': {
        'plugins': {
          'legend': {'position': 'bottom'},
        },
      },
    };
  }
}
