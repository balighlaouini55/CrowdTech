// Moteur de prix du jeton et de conversion de devises.
// Les taux viennent d'ExchangeRate-API (gratuite, sans clé) ; ils sont mis
// en cache dans SQLite pendant 12 h, avec des taux de secours hors ligne.

import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';

/// Taux de change depuis l'euro et leur origine.
class ExchangeRates {
  final Map<String, double> rates;

  /// « ExchangeRate-API », « cache » ou « taux de secours ».
  final String source;
  final DateTime fetchedAt;
  const ExchangeRates(this.rates, this.source, this.fetchedAt);

  /// Taux d'une devise depuis l'euro. Une devise absente de la réponse de
  /// l'API utilise le taux de secours, jamais 1:1 (1 € ≠ 1 DT).
  double rateOf(String currency) => currency == 'EUR'
      ? 1
      : rates[currency] ?? CurrencyService.fallbackRates[currency] ?? 1;
}

class CurrencyService {
  CurrencyService._();

  /// Devises proposées dans l'application.
  static const currencies = ['EUR', 'TND', 'USD', 'GBP', 'MAD', 'DZD', 'CAD'];

  static const symbols = {
    'EUR': '€',
    'TND': 'DT',
    'USD': r'$',
    'GBP': '£',
    'MAD': 'MAD',
    'DZD': 'DA',
    'CAD': r'CA$',
  };

  /// Taux approximatifs utilisés si l'API et le cache sont indisponibles.
  static const fallbackRates = {
    'TND': 3.38,
    'USD': 1.08,
    'GBP': 0.85,
    'MAD': 10.9,
    'DZD': 145.0,
    'CAD': 1.48,
  };

  static const cacheDuration = Duration(hours: 12);

  /// Taux depuis l'euro : cache récent, sinon API, sinon taux de secours.
  static Future<ExchangeRates> load({bool forceRefresh = false}) async {
    final cached = (await FundingRepository.exchangeRates.all()).lastOrNull;
    final cachedAt = DateTime.tryParse(cached?['fetchedAt']?.toString() ?? '');
    Map<String, double> ratesOf(Map<String, Object?> row) => {
      for (final MapEntry(:key, :value)
          in (row['rates'] as Map? ?? const {}).entries)
        if (value is num) key.toString(): value.toDouble(),
    };
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < cacheDuration) {
      return ExchangeRates(ratesOf(cached), 'cache', cachedAt);
    }
    try {
      final all = await CrowdTechApi.fetchExchangeRates();
      final rates = {
        for (final currency in currencies) currency: ?all[currency],
      };
      final now = DateTime.now();
      final payload = {'base': 'EUR', 'rates': rates, 'fetchedAt': '$now'};
      final id = cached?['id'];
      if (id is int) {
        await FundingRepository.exchangeRates.update(id, payload);
      } else {
        await FundingRepository.exchangeRates.add(payload);
      }
      return ExchangeRates(rates, 'ExchangeRate-API', now);
    } on Exception {
      if (cached != null && cachedAt != null) {
        return ExchangeRates(ratesOf(cached), 'cache', cachedAt);
      }
      return ExchangeRates(fallbackRates, 'taux de secours', DateTime.now());
    }
  }

  /// Convertit un montant d'une devise à une autre.
  static double convert(
    double amount,
    String from,
    String to,
    ExchangeRates rates,
  ) => amount / rates.rateOf(from) * rates.rateOf(to);

  /// Montant formaté avec le symbole de la devise.
  static String format(double amount, String currency) {
    final fixed = amount >= 1000
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final digits = fixed.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '${digits.replaceAll('.', ',')} ${symbols[currency] ?? currency}';
  }
}

/// Moteur de fixation du prix du jeton.
class TokenPricing {
  TokenPricing._();

  /// Prix unitaire proposé pour un objectif : on vise environ
  /// [targetTokens] jetons, arrondi à un prix « rond » (1, 2, 5, 10…).
  static double suggestedPrice(double goal, {int targetTokens = 1000}) {
    if (goal <= 0) return 1;
    final raw = goal / targetTokens;
    const steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];
    for (final step in steps) {
      if (raw <= step) return step.toDouble();
    }
    return (raw / 1000).ceil() * 1000.0;
  }

  /// Nombre de jetons émis pour un objectif à ce prix.
  static int supply(double goal, double tokenPrice) =>
      tokenPrice <= 0 ? 0 : (goal / tokenPrice).floor();

  /// Jetons qu'un budget (dans n'importe quelle devise) permet d'acheter,
  /// et le reste non utilisé (dans la même devise).
  static ({int tokens, double change}) tokensForBudget({
    required double budget,
    required String currency,
    required double tokenPriceEur,
    required ExchangeRates rates,
  }) {
    if (tokenPriceEur <= 0 || budget <= 0) return (tokens: 0, change: budget);
    final budgetEur = CurrencyService.convert(budget, currency, 'EUR', rates);
    final tokens = (budgetEur / tokenPriceEur + 1e-9).floor();
    final spentEur = tokens * tokenPriceEur;
    return (
      tokens: tokens,
      change: CurrencyService.convert(
        budgetEur - spentEur,
        'EUR',
        currency,
        rates,
      ),
    );
  }
}
