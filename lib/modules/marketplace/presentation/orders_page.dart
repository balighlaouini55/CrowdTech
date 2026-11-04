// Suivi des commandes avec séquestre (Escrow) : achats, ventes et litiges.
// Chaque commande affiche sa frise d'états, son QR code et les actions
// permises (expédier, confirmer, annuler, signaler un problème, noter).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';
import 'package:crowdtech/modules/marketplace/domain/product_order.dart';
import 'package:crowdtech/modules/marketplace/domain/seller_reputation.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/input_dialog.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/network_visuals.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:crowdtech/shared/widgets/star_rating.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatefulWidget {
  final String accountKey;

  /// Onglet ouvert au départ : 0 achats, 1 ventes, 2 litiges (admin).
  final int initialTab;
  const OrdersPage({required this.accountKey, this.initialTab = 0, super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool loading = true;
  List<Map<String, Object?>> orders = [];

  /// Avis déjà donnés : (commande, vendeur).
  Set<(Object?, String)> reviewed = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await OrderEscrow.autoRelease();
    final rows = await MarketplaceRepository.orders.all();
    final reviews = await MarketplaceRepository.sellerReviews.all();
    if (!mounted) return;
    setState(() {
      orders = rows.reversed.toList();
      reviewed = {
        for (final row in reviews)
          (row['orderId'], row['sellerKey']?.toString() ?? ''),
      };
      loading = false;
    });
  }

  List<Map<String, Object?>> get purchases =>
      orders.where((row) => row['ownerKey'] == widget.accountKey).toList();

  List<Map<String, Object?>> get sales => orders
      .where((row) => OrderEscrow.sellersOf(row).contains(widget.accountKey))
      .toList();

  List<Map<String, Object?>> get disputes =>
      orders.where((row) => OrderState.of(row) == OrderState.disputed).toList();

  Future<void> act(Map<String, Object?> order, OrderAction action) async {
    var note = '';
    if (action == OrderAction.dispute) {
      final values = await showInputDialog(
        context,
        title: 'Quel est le problème ?',
        confirmLabel: 'Ouvrir le litige',
        fields: const [DialogField('Décrivez le problème', multiline: true)],
      );
      if (values == null) return;
      note = values.first;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${action.label} ?'),
          content: Text(switch (action) {
            OrderAction.confirm =>
              'Les fonds seront libérés au vendeur. Confirmez seulement si '
                  'vous avez bien reçu votre colis.',
            OrderAction.cancel =>
              'La commande est annulée et l’acheteur est remboursé.',
            OrderAction.refund =>
              'L’acheteur est remboursé et le stock remis en vente.',
            OrderAction.release => 'Le vendeur reçoit le paiement.',
            _ => 'L’acheteur sera informé de l’expédition.',
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      final updated = await OrderEscrow.apply(
        order['id']! as int,
        action,
        note: note,
      );
      await load();
      if (!mounted) return;
      context.showMessage('Commande « ${OrderState.of(updated)} ».');
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  Future<void> rateSeller(Map<String, Object?> order, String sellerKey) async {
    final result = await showDialog<({int stars, String comment})>(
      context: context,
      builder: (_) => _SellerReviewDialog(sellerKey: sellerKey),
    );
    if (result == null) return;
    final (:stars, :comment) = result;
    try {
      await SellerReputationService.review(
        order: order,
        sellerKey: sellerKey,
        stars: stars,
        comment: comment,
      );
      await load();
      if (!mounted) return;
      context.showMessage('Merci pour votre avis ⭐');
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Mes achats', purchases),
      ('Mes ventes', sales),
      if (Permissions.isAdmin) ('Litiges', disputes),
    ];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suivi des commandes'),
          bottom: TabBar(
            labelColor: ModulePalette.store.start,
            indicatorColor: ModulePalette.store.start,
            tabs: [
              for (final (label, rows) in tabs)
                Tab(text: '$label (${rows.length})'),
            ],
          ),
        ),
        body: loading
            ? const LoadingSkeleton()
            : TabBarView(
                children: [
                  for (final (label, rows) in tabs)
                    rows.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            message: label == 'Mes ventes'
                                ? 'Aucune vente pour l’instant.'
                                : label == 'Litiges'
                                ? 'Aucun litige en cours 🎉'
                                : 'Aucune commande pour l’instant.',
                            palette: ModulePalette.store,
                          )
                        : RefreshIndicator(
                            onRefresh: load,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                for (final order in rows) _orderCard(order),
                              ],
                            ),
                          ),
                ],
              ),
      ),
    );
  }

  Widget _orderCard(Map<String, Object?> order) {
    final details = ProductOrder.fromMap(order);
    final state = OrderState.of(order);
    final actions = OrderEscrow.availableActions(order, widget.accountKey);
    final isBuyer = details.buyerKey == widget.accountKey;
    final toReview = isBuyer && state == OrderState.completed
        ? [
            for (final seller in details.sellerKeys)
              if (!reviewed.contains((details.id, seller))) seller,
          ]
        : const <String>[];
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text('${details.code} · ${formatMoney(details.total)}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _StateChip(state),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  formatDate(details.createdAt),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        children: [
          _Timeline(state),
          const SizedBox(height: 12),
          for (final line in details.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${line.productName} × ${line.quantity}',
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
          if (details.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '📍 ${details.address}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          if (state == OrderState.held)
            const _Info(
              '🔒 Paiement conservé en séquestre : le vendeur est payé quand '
              'vous confirmez la réception.',
            ),
          if (state == OrderState.shipped)
            const _Info(
              '🛡️ Protection acheteur : sans action de votre part, les fonds '
              'sont libérés ${OrderEscrow.protectionDays} jours après '
              'l’expédition.',
            ),
          const SizedBox(height: 12),
          Center(child: QrCodeImage(details.code, size: 130)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                action == OrderAction.cancel ||
                        action == OrderAction.dispute ||
                        action == OrderAction.refund
                    ? OutlinedButton(
                        onPressed: () => act(order, action),
                        child: Text(action.label),
                      )
                    : FilledButton(
                        onPressed: () => act(order, action),
                        style: FilledButton.styleFrom(
                          backgroundColor: ModulePalette.store.start,
                        ),
                        child: Text(action.label),
                      ),
              for (final seller in toReview)
                FilledButton.tonalIcon(
                  onPressed: () => rateSeller(order, seller),
                  icon: const Icon(Icons.star_rounded),
                  label: Text('Noter ${seller.split('@').first}'),
                ),
            ],
          ),
          _History(details.history),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String state;
  const _StateChip(this.state);

  @override
  Widget build(BuildContext context) {
    final (color, soft) = switch (state) {
      OrderState.completed => (AppColors.success, AppColors.successSoft),
      OrderState.disputed => (AppColors.danger, AppColors.dangerSoft),
      OrderState.cancelled ||
      OrderState.refunded => (AppColors.muted, AppColors.border),
      OrderState.shipped => (AppColors.info, AppColors.infoSoft),
      _ => (AppColors.warning, AppColors.warningSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Frise : Fonds bloqués → Expédiée → Terminée.
class _Timeline extends StatelessWidget {
  final String state;
  const _Timeline(this.state);

  @override
  Widget build(BuildContext context) {
    final path = OrderState.happyPath;
    final reached = switch (state) {
      OrderState.disputed || OrderState.refunded => 1,
      OrderState.cancelled => -1,
      _ => path.indexOf(state),
    };
    return Row(
      children: [
        for (final (index, step) in path.indexed) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 3,
                color: index <= reached
                    ? ModulePalette.store.start
                    : AppColors.border,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: index <= reached
                    ? ModulePalette.store.start
                    : AppColors.border,
                child: Icon(
                  [
                    Icons.lock_rounded,
                    Icons.local_shipping_rounded,
                    Icons.check_rounded,
                  ][index],
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step,
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final String text;
  const _Info(this.text);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ModulePalette.store.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12.5)),
  );
}

class _History extends StatelessWidget {
  final List<OrderEvent> history;
  const _History(this.history);

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          for (final entry in history.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${formatDateTime(entry.at)} — ${entry.action}'
                '${entry.note == null ? '' : ' : ${entry.note}'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Note et avis sur un vendeur. Le dialogue possède son contrôleur : il est
/// libéré quand le dialogue disparaît vraiment, après l'animation.
class _SellerReviewDialog extends StatefulWidget {
  final String sellerKey;
  const _SellerReviewDialog({required this.sellerKey});

  @override
  State<_SellerReviewDialog> createState() => _SellerReviewDialogState();
}

class _SellerReviewDialogState extends State<_SellerReviewDialog> {
  int stars = 5;
  final commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Noter le vendeur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.sellerKey,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          StarPicker(
            value: stars,
            onChanged: (value) => setState(() => stars = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Votre avis (facultatif)',
            ),
          ),
          SpellCheckButton(controller: commentController),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            stars: stars,
            comment: commentController.text,
          )),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
