// Portefeuille de l'utilisateur : total investi, jetons, projets soutenus
// (avec palier de contrepartie et revente), nouvelles des projets,
// historique des opérations et attestations.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/modules/funding/domain/portfolio_analytics.dart';
import 'package:crowdtech/modules/funding/presentation/certificate_page.dart';
import 'package:crowdtech/modules/funding/presentation/token_market_page.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class PortfolioPage extends StatefulWidget {
  final String accountKey;
  const PortfolioPage({required this.accountKey, super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  bool loading = true;
  String? error;

  /// Toutes mes opérations (remboursées comprises), de la plus récente.
  List<Map<String, Object?>> investments = [];
  List<Map<String, Object?>> news = [];

  List<Map<String, Object?>> get active =>
      investments.where(CrowdRules.isActive).toList();

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
      final mine = (await FundingRepository.investments.ownedBy(
        widget.accountKey,
      )).reversed.toList();
      final updates = await CrowdRules.updatesFor({
        for (final row in mine)
          if (CrowdRules.isActive(row) && row['projectId'] is int)
            row['projectId']! as int,
      });
      if (!mounted) return;
      setState(() {
        investments = mine;
        news = updates;
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger le portefeuille : $exception';
        loading = false;
      });
    }
  }

  num sumOf(Iterable<Map<String, Object?>> rows, String key) =>
      rows.fold<num>(0, (sum, row) => sum + ((row[key] as num?) ?? 0));

  Future<void> sell(int projectId, String title) async {
    final published = await sellTokensDialog(
      context,
      projectId: projectId,
      projectTitle: title,
      accountKey: widget.accountKey,
    );
    if (published) await load();
  }

  /// Évolution du portefeuille (QuickChart) et projection sur 3 ans.
  Widget _evolutionCard() {
    final points = PortfolioAnalytics.evolution(investments);
    if (points.isEmpty) return const SizedBox.shrink();
    final total = points.last.invested;
    final projected = PortfolioAnalytics.projectedValue(total, 8, 3);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution de mon portefeuille 📈',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            QuickChartImage(
              config: PortfolioAnalytics.chartConfig(points),
              fallback: Center(
                child: Text(
                  '${points.length} jour(s) d’investissement · '
                  '${formatMoney(total)} investis',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Simulation à 8 %/an : ${formatMoney(projected)} dans 3 ans '
              '(ROI +${PortfolioAnalytics.roiPercent(total, projected).toStringAsFixed(0)} %). '
              'Estimation indicative, non garantie.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Regroupement par projet (opérations actives uniquement).
    final byProject = <int, List<Map<String, Object?>>>{};
    for (final investment in active) {
      final id = investment['projectId'];
      if (id is int) byProject.putIfAbsent(id, () => []).add(investment);
    }
    final refunded = investments.where((row) => !CrowdRules.isActive(row));
    return Scaffold(
      appBar: AppBar(title: const Text('Mon portefeuille')),
      body: loading
          ? const LoadingSkeleton()
          : error != null
          ? DatabaseErrorView(message: error!, onRetry: load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ScreenHeader(
                  title: 'Mes investissements',
                  subtitle: 'Les projets que vous soutenez avec vos jetons.',
                  icon: Icons.account_balance_wallet_rounded,
                  stats: [
                    (formatMoney(sumOf(active, 'amount')), 'investis'),
                    ('${sumOf(active, 'tokens').toInt()}', 'jetons'),
                    ('${byProject.length}', 'projets'),
                  ],
                ),
                if (active.isNotEmpty) _evolutionCard(),
                if (refunded.isNotEmpty)
                  Card(
                    color: AppColors.infoSoft,
                    child: ListTile(
                      leading: const Text('↩️', style: TextStyle(fontSize: 22)),
                      title: Text(
                        '${formatMoney(sumOf(refunded, 'amount'))} remboursés',
                      ),
                      subtitle: const Text(
                        'Collecte(s) échouée(s) : règle du « tout ou rien ».',
                      ),
                    ),
                  ),
                if (investments.isEmpty)
                  const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    message:
                        'Aucun jeton investi pour le moment.\n'
                        'Choisissez un projet et achetez votre premier pack !',
                  ),
                if (byProject.isNotEmpty) const _Title('Projets soutenus'),
                for (final (index, MapEntry(key: id, value: rows))
                    in byProject.entries.indexed)
                  FadeSlideIn(index: index, child: _projectTile(id, rows)),
                if (news.isNotEmpty) ...[
                  const _Title('Nouvelles de mes projets'),
                  for (final update in news.take(5))
                    Card(
                      child: ListTile(
                        leading: const Text(
                          '📣',
                          style: TextStyle(fontSize: 22),
                        ),
                        title: Text('${update['title']}'),
                        subtitle: Text(
                          '${update['projectTitle']} • '
                          '${formatDate(update['createdAt']?.toString())}\n'
                          '${update['text']}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
                if (investments.isNotEmpty)
                  const _Title('Historique des achats'),
                for (final investment in investments) _historyTile(investment),
              ],
            ),
    );
  }

  Widget _projectTile(int projectId, List<Map<String, Object?>> rows) {
    final title = rows.first['projectTitle']?.toString() ?? 'Projet';
    final amount = sumOf(rows, 'amount').toDouble();
    final tokens = sumOf(rows, 'tokens').toInt();
    final tier = CrowdRules.tierFor(amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ModulePalette.funding.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${rows.length} opération(s) • ${formatMoney(amount)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge('$tokens jetons', icon: Icons.toll_rounded),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (tier != null)
                  StatusBadge(
                    '${tier.emoji} ${tier.name}',
                    tone: BadgeTone.success,
                  ),
                const Spacer(),
                if (tokens > 0)
                  TextButton.icon(
                    onPressed: () => sell(projectId, title),
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('Revendre'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(Map<String, Object?> investment) {
    final refunded = !CrowdRules.isActive(investment);
    final tokens = (investment['tokens'] as num?)?.toInt() ?? 0;
    final type = investment['type']?.toString();
    final label = switch (type) {
      'Achat' => 'Achat de jetons (revente)',
      'Vente' => 'Vente de jetons',
      _ => 'Pack ${investment['pack'] ?? ''}',
    };
    return Card(
      child: ListTile(
        onTap: type == 'Achat' || type == 'Vente'
            ? null
            : () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CertificatePage(investment: investment),
                ),
              ),
        leading: CircleAvatar(
          backgroundColor: refunded
              ? AppColors.infoSoft
              : AppColors.primarySoft,
          child: Icon(
            refunded
                ? Icons.undo_rounded
                : type == 'Vente'
                ? Icons.sell_rounded
                : Icons.shopping_bag_rounded,
            color: refunded ? AppColors.info : AppColors.primary,
          ),
        ),
        title: Text('$label • ${investment['projectTitle'] ?? ''}'),
        subtitle: Text(
          refunded
              ? 'Remboursé le ${formatDate(investment['refundedAt']?.toString())}'
              : type == null || type == 'Pack'
              ? '${formatDateTime(investment['createdAt']?.toString())} • '
                    'attestation 📜'
              : formatDateTime(investment['createdAt']?.toString()),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney((investment['amount'] as num?) ?? 0),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                decoration: refunded ? TextDecoration.lineThrough : null,
              ),
            ),
            Text(
              '${tokens >= 0 ? '+' : ''}$tokens jetons',
              style: TextStyle(
                color: tokens >= 0 ? AppColors.success : AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
