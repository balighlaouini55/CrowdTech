// Simulateur de rendement (chaque calcul est enregistré).
//
// Calcul composé : valeur = montant × (1 + taux)^années. Le taux peut être
// négatif pour simuler une perte (risque réel du crowdfunding). L'inflation
// du pays (Banque mondiale) donne le rendement réel, en pouvoir d'achat.

import 'dart:math' as math;

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/data/funding_web_api.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

/// Valeur estimée après [years] années à [ratePercent] % par an (composé).
double compoundValue(double amount, double ratePercent, int years) =>
    amount * math.pow(1 + ratePercent / 100, years);

class RoiSimulatorPage extends StatefulWidget {
  const RoiSimulatorPage({super.key});

  @override
  State<RoiSimulatorPage> createState() => _RoiSimulatorPageState();
}

class _RoiSimulatorPageState extends State<RoiSimulatorPage> {
  final amountController = TextEditingController();
  final rateController = TextEditingController(text: '5');
  final yearsController = TextEditingController(text: '1');
  final formKey = GlobalKey<FormState>();
  double? estimate;
  double? invested;

  /// Pays dont l'inflation est déduite (Banque mondiale).
  String country = 'TN';
  Inflation? inflation;
  String? inflationNote;

  static const countries = {
    'TN': 'Tunisie',
    'FR': 'France',
    'MA': 'Maroc',
    'DZ': 'Algérie',
    'BE': 'Belgique',
    'CA': 'Canada',
  };

  @override
  void dispose() {
    amountController.dispose();
    rateController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  /// Accepte « 12,5 » comme « 12.5 ».
  static double? parseNumber(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  Future<void> calculate() async {
    if (!formKey.currentState!.validate()) return;
    final amount = parseNumber(amountController.text)!;
    final ratePercent = parseNumber(rateController.text)!;
    final years = int.parse(yearsController.text.trim());
    final result = compoundValue(amount, ratePercent, years);
    setState(() {
      estimate = result;
      invested = amount;
      inflation = null;
      inflationNote = 'Recherche de l’inflation…';
    });
    // Inflation du pays (Banque mondiale) : rendement réel.
    try {
      final found = await FundingWebApi.inflation(country);
      if (!mounted) return;
      setState(() {
        inflation = found;
        inflationNote = found == null
            ? 'Inflation inconnue pour ce pays.'
            : null;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => inflationNote = 'Inflation indisponible hors ligne.');
    }
    final realEstimate = inflation == null
        ? null
        : PortfolioAnalytics.realValue(
            amount,
            ratePercent,
            inflation!.percent,
            years,
          );
    try {
      await FundingRepository.simulations.add({
        'title': 'Simulation de ${formatMoney(amount)}',
        'amount': amount,
        'ratePercent': ratePercent,
        'years': years,
        'estimate': double.parse(result.toStringAsFixed(2)),
        'country': country,
        if (inflation case final found?)
          'inflationPercent': double.parse(found.percent.toStringAsFixed(2)),
        if (realEstimate != null)
          'realEstimate': double.parse(realEstimate.toStringAsFixed(2)),
        'ownerKey': CrowdTechSession.accountKey,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Simulation non enregistrée : $error');
    }
  }

  String? validateAmount(String? value) {
    final amount = parseNumber(value);
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Saisissez une valeur positive.';
    }
    if (amount > 10000000) return 'Maximum 10 000 000 €.';
    return null;
  }

  String? validateRate(String? value) {
    final rate = parseNumber(value);
    if (rate == null || !rate.isFinite) return 'Saisissez un taux valide.';
    if (rate <= -100 || rate > 100) {
      return 'Le taux doit être entre −99 % et 100 %.';
    }
    return null;
  }

  String? validateYears(String? value) {
    final years = int.tryParse((value ?? '').trim());
    if (years == null || years < 1) return 'Saisissez une valeur positive.';
    if (years > 50) return 'Maximum 50 ans.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulateur de rendement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ScreenHeader(
            title: 'Et si j’investissais ?',
            subtitle:
                'Simulation indicative uniquement : aucun rendement n’est '
                'garanti. Essayez aussi un taux négatif pour voir le risque.',
            icon: Icons.calculate_rounded,
          ),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant investi (€)',
                    prefixIcon: Icon(Icons.euro_rounded),
                  ),
                  validator: validateAmount,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Variation annuelle simulée (%)',
                    helperText: 'Négatif = perte (ex. −20)',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  validator: validateRate,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (années)',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  validator: validateYears,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: country,
                  decoration: const InputDecoration(
                    labelText: 'Pays (inflation déduite)',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                  items: [
                    for (final MapEntry(:key, :value) in countries.entries)
                      DropdownMenuItem(value: key, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => country = value ?? 'TN'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: calculate,
                    icon: const Icon(Icons.auto_graph_rounded),
                    label: const Text('Calculer la simulation'),
                  ),
                ),
              ],
            ),
          ),
          if (estimate case final value?) ...[
            const SizedBox(height: 20),
            _result(value, invested ?? 0),
          ],
        ],
      ),
    );
  }

  Widget _result(double value, double amount) {
    final difference = value - amount;
    final gain = difference >= 0;
    final color = gain ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: softShadow,
      ),
      child: Column(
        children: [
          Text(gain ? '📈' : '📉', style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          const Text(
            'Valeur indicative',
            style: TextStyle(color: AppColors.muted),
          ),
          Text(
            formatMoney(double.parse(value.toStringAsFixed(2))),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: gain ? AppColors.successSoft : AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${gain ? '+' : '−'}'
              '${formatMoney(double.parse(difference.abs().toStringAsFixed(2)))}'
              ' ${gain ? 'de gain' : 'de perte'}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          _inflationLine(amount),
          const SizedBox(height: 16),
          _yearlyChart(amount),
        ],
      ),
    );
  }

  /// Rendement réel une fois l'inflation du pays déduite (Fisher).
  Widget _inflationLine(double amount) {
    final found = inflation;
    final note = inflationNote;
    if (found == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          note ?? '',
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
      );
    }
    final rate = parseNumber(rateController.text) ?? 0;
    final years = int.tryParse(yearsController.text.trim()) ?? 1;
    final real = PortfolioAnalytics.realRatePercent(rate, found.percent);
    final realValue = PortfolioAnalytics.realValue(
      amount,
      rate,
      found.percent,
      years,
    );
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Inflation ${found.country} (${found.year}) : '
        '${found.percent.toStringAsFixed(1)} %/an.\n'
        'Rendement réel : ${real.toStringAsFixed(2)} %/an → '
        '${formatMoney(double.parse(realValue.toStringAsFixed(2)))} '
        'en pouvoir d’achat d’aujourd’hui.',
        style: const TextStyle(color: AppColors.ink, height: 1.4),
      ),
    );
  }

  /// Valeur année par année (graphique QuickChart, gratuit).
  Widget _yearlyChart(double amount) {
    final rate = parseNumber(rateController.text) ?? 0;
    final years = (int.tryParse(yearsController.text.trim()) ?? 1).clamp(1, 30);
    return QuickChartImage(
      height: 200,
      config: {
        'type': 'bar',
        'data': {
          'labels': [for (var year = 0; year <= years; year++) 'An $year'],
          'datasets': [
            {
              'label': 'Valeur (€)',
              'data': [
                for (var year = 0; year <= years; year++)
                  compoundValue(amount, rate, year).round(),
              ],
              'backgroundColor': '#B57CF6',
              'borderRadius': 8,
            },
          ],
        },
        'options': {
          'plugins': {
            'legend': {'display': false},
          },
        },
      },
      fallback: const SizedBox.shrink(),
    );
  }
}
