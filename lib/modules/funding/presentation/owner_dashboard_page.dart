// Tableau de bord du porteur : chiffres clés et collecte des 14 derniers
// jours pour chacun de ses projets (l'admin voit tous les projets).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

/// Montant collecté par jour sur les [days] derniers jours (aujourd'hui en
/// dernier). Seuls les achats de packs comptent (pas les reventes).
List<double> dailyAmounts(List<Map<String, Object?>> investments, int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final totals = List<double>.filled(days, 0);
  for (final row in investments) {
    if (row['type'] == 'Achat' || row['type'] == 'Vente') continue;
    final date = DateTime.tryParse(row['createdAt']?.toString() ?? '');
    if (date == null) continue;
    final age = today
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (age < 0 || age >= days) continue;
    totals[days - 1 - age] += (row['amount'] as num?)?.toDouble() ?? 0;
  }
  return totals;
}

class OwnerDashboardPage extends StatefulWidget {
  final String accountKey;
  const OwnerDashboardPage({required this.accountKey, super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  bool loading = true;
  List<FundingProject> projects = [];
  List<Map<String, Object?>> investments = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await FundingRepository.projects.all();
    final active = await CrowdRules.activeInvestments();
    if (!mounted) return;
    setState(() {
      projects = rows
          .map(FundingProject.fromMap)
          .where(
            (project) =>
                Permissions.isAdmin || project.ownerKey == widget.accountKey,
          )
          .toList();
      investments = active;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord porteur')),
      body: loading
          ? const LoadingSkeleton()
          : projects.isEmpty
          ? const EmptyState(
              icon: Icons.insights_rounded,
              message:
                  'Vous n’avez pas encore de projet.\n'
                  'Publiez-en un avec le bouton + du Crowdfunding.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final project in projects)
                  _ProjectStats(
                    project: project,
                    investments: [
                      for (final row in investments)
                        if (row['projectId'] == project.id) row,
                    ],
                  ),
              ],
            ),
    );
  }
}

class _ProjectStats extends StatelessWidget {
  final FundingProject project;
  final List<Map<String, Object?>> investments;
  const _ProjectStats({required this.project, required this.investments});

  @override
  Widget build(BuildContext context) {
    final packs = investments.where((row) => row['type'] != 'Achat');
    final purchases = packs.where((row) => row['type'] != 'Vente').toList();
    final contributors = {
      for (final row in investments)
        if (((row['tokens'] as num?) ?? 0) > 0) row['ownerKey'],
    }.length;
    final packCounts = <String, int>{};
    for (final row in purchases) {
      final name = row['pack']?.toString() ?? 'Pack';
      packCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
    final bestPack = packCounts.entries.isEmpty
        ? '—'
        : (packCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    final daily = dailyAmounts(investments, 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: project.title,
          subtitle:
              '${project.statusLabel} • ${project.progress} % de '
              '${formatMoney(project.goal)}',
          icon: Icons.insights_rounded,
          stats: [
            (formatMoney(project.amountRaised), 'collectés'),
            ('$contributors', 'contributeurs'),
            ('${purchases.length}', 'packs vendus'),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Collecte des 14 derniers jours',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Total sur la période : '
                  '${formatMoney(daily.fold<double>(0, (a, b) => a + b))} • '
                  'pack préféré : $bestPack',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                DailyBarChart(values: daily),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showTable(context, daily),
                    icon: const Icon(Icons.table_rows_outlined, size: 18),
                    label: const Text('Voir le détail'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (packCounts.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final MapEntry(:key, :value) in packCounts.entries)
                    StatusBadge('$key × $value', icon: Icons.toll_rounded),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Vue en tableau (accessibilité) : un jour par ligne.
  void _showTable(BuildContext context, List<double> daily) {
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          for (var index = daily.length - 1; index >= 0; index--)
            ListTile(
              dense: true,
              title: Text(
                formatDate(
                  isoDate(
                    now.subtract(Duration(days: daily.length - 1 - index)),
                  ),
                ),
              ),
              trailing: Text(
                formatMoney(daily[index]),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Histogramme simple : une barre par jour, une seule couleur, valeur au
/// toucher (infobulle), maximum indiqué sur l'axe.
class DailyBarChart extends StatelessWidget {
  final List<double> values;
  final double height;
  const DailyBarChart({required this.values, this.height = 140, super.key});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final now = DateTime.now();
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Axe recessif : seulement le maximum et zéro.
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      maxValue == 0 ? '' : formatMoney(maxValue),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                    const Text(
                      '0 €',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (index, value) in values.indexed)
                        Expanded(
                          child: Tooltip(
                            message:
                                '${formatDate(isoDate(now.subtract(Duration(days: values.length - 1 - index))))} : '
                                '${formatMoney(value)}',
                            child: Padding(
                              // 2 px d'écart entre les barres.
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: Container(
                                height: maxValue == 0
                                    ? 0
                                    : (value / maxValue * height).clamp(
                                        value > 0 ? 3 : 0,
                                        height,
                                      ),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            SizedBox(width: 62),
            Text(
              'il y a 14 j',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            Spacer(),
            Text(
              'aujourd’hui',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}
