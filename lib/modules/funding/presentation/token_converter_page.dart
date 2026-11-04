// Prix du jeton dans plusieurs devises et convertisseur budget → jetons
// (taux ExchangeRate-API), évolution sur 30 jours (Frankfurter).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/currency_service.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/funding/presentation/widgets/rate_history_section.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class TokenConverterPage extends StatefulWidget {
  final FundingProject project;
  const TokenConverterPage({required this.project, super.key});

  @override
  State<TokenConverterPage> createState() => _TokenConverterPageState();
}

class _TokenConverterPageState extends State<TokenConverterPage> {
  ExchangeRates? rates;
  final budgetController = TextEditingController(text: '100');
  String currency = 'TND';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    final loaded = await CurrencyService.load(forceRefresh: refresh);
    if (mounted) setState(() => rates = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final current = rates;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prix du jeton'),
        actions: [
          IconButton(
            tooltip: 'Actualiser les taux',
            onPressed: () => load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: current == null
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ScreenHeader(
                  title: project.title,
                  subtitle: 'Prix unitaire du jeton et conversion en devises.',
                  icon: Icons.currency_exchange_rounded,
                  stats: [
                    (formatMoney(project.tokenPrice), 'le jeton'),
                    (
                      '${TokenPricing.supply(project.goal, project.tokenPrice)}',
                      'jetons émis',
                    ),
                  ],
                ),
                FormSection(
                  title: 'Le jeton dans votre devise',
                  icon: Icons.payments_outlined,
                  children: [
                    for (final code in CurrencyService.currencies)
                      Row(
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CurrencyService.format(
                              CurrencyService.convert(
                                project.tokenPrice,
                                'EUR',
                                code,
                                current,
                              ),
                              code,
                            ),
                            style: TextStyle(
                              color: ModulePalette.funding.start,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    Text(
                      'Source : ${current.source} · '
                      '${formatDateTime(current.fetchedAt.toIso8601String())}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                RateHistorySection(tokenPrice: project.tokenPrice),
                FormSection(
                  title: 'Combien de jetons pour mon budget ?',
                  icon: Icons.calculate_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: budgetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Budget',
                              prefixIcon: Icon(Icons.savings_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: currency,
                            decoration: const InputDecoration(
                              labelText: 'Devise',
                            ),
                            items: [
                              for (final code in CurrencyService.currencies)
                                DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => currency = value ?? 'EUR'),
                          ),
                        ),
                      ],
                    ),
                    _BudgetResult(
                      budget:
                          double.tryParse(
                            budgetController.text.replaceAll(',', '.'),
                          ) ??
                          0,
                      currency: currency,
                      tokenPrice: project.tokenPrice,
                      rates: current,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _BudgetResult extends StatelessWidget {
  final double budget;
  final String currency;
  final double tokenPrice;
  final ExchangeRates rates;
  const _BudgetResult({
    required this.budget,
    required this.currency,
    required this.tokenPrice,
    required this.rates,
  });

  @override
  Widget build(BuildContext context) {
    final result = TokenPricing.tokensForBudget(
      budget: budget,
      currency: currency,
      tokenPriceEur: tokenPrice,
      rates: rates,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModulePalette.funding.soft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.tokens} jeton(s)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ModulePalette.funding.start,
                  ),
                ),
                Text(
                  'Reste : ${CurrencyService.format(result.change, currency)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
