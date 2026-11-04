// Évolution du prix d'un jeton dans une devise sur 30 jours : taux de la
// BCE (Frankfurter) et graphique QuickChart.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crowdtech/modules/funding/data/funding_web_api.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:flutter/material.dart';

class RateHistorySection extends StatefulWidget {
  final double tokenPrice;
  const RateHistorySection({required this.tokenPrice, super.key});

  @override
  State<RateHistorySection> createState() => _RateHistorySectionState();
}

class _RateHistorySectionState extends State<RateHistorySection> {
  String currency = FundingWebApi.historyCurrencies.first;
  List<DailyRate>? history;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      history = await FundingWebApi.rateHistory(currency);
    } on ApiException catch (exception) {
      history = null;
      error = 'Historique indisponible : $exception';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final points = history ?? const <DailyRate>[];
    final variation = PortfolioAnalytics.variationPercent([
      for (final point in points) point.rate,
    ]);
    final up = variation >= 0;
    return FormSection(
      title: 'Évolution sur 30 jours',
      icon: Icons.show_chart_rounded,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final code in FundingWebApi.historyCurrencies)
              ChoiceChip(
                label: Text(code),
                selected: code == currency,
                onSelected: (_) {
                  setState(() => currency = code);
                  load();
                },
              ),
          ],
        ),
        if (loading)
          const LinearProgressIndicator()
        else if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.muted))
        else if (points.length >= 2) ...[
          Text(
            '${up ? '▲' : '▼'} ${variation.abs().toStringAsFixed(2)} % '
            'en 30 jours : le jeton coûte '
            '${(widget.tokenPrice * points.last.rate).toStringAsFixed(2)} '
            '$currency aujourd’hui.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: up ? AppColors.danger : AppColors.success,
            ),
          ),
          QuickChartImage(
            config: PortfolioAnalytics.tokenPriceChart(
              tokenPrice: widget.tokenPrice,
              currency: currency,
              history: points,
            ),
          ),
        ],
        const Text(
          'Taux de la Banque centrale européenne (Frankfurter). Le dinar '
          'tunisien n’y figure pas : voir le tableau ci-dessus.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
