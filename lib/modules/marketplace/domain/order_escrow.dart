// Machine à états des commandes (State Escrow Pattern).
//
//   Fonds bloqués ──expédier──▶ Expédiée ──confirmer réception──▶ Terminée
//        │                         │                              (fonds libérés)
//      annuler                 ouvrir un litige
//        ▼                         ▼
//     Annulée                   Litige ──rembourser──▶ Remboursée
//                                  └──libérer──▶ Terminée
//
// L'argent de l'acheteur reste « bloqué » jusqu'à la confirmation de
// réception (ou la fin du délai de protection), puis il est libéré au vendeur.

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';

/// États possibles d'une commande.
class OrderState {
  OrderState._();
  static const held = 'Fonds bloqués';
  static const shipped = 'Expédiée';
  static const completed = 'Terminée';
  static const cancelled = 'Annulée';
  static const disputed = 'Litige';
  static const refunded = 'Remboursée';

  /// Étapes du parcours normal, pour la frise d'avancement.
  static const happyPath = [held, shipped, completed];

  /// Une ancienne commande (avant l'escrow) est traitée comme « bloquée ».
  static String of(Map<String, Object?> order) {
    final status = order['status']?.toString() ?? '';
    return const {
          held,
          shipped,
          completed,
          cancelled,
          disputed,
          refunded,
        }.contains(status)
        ? status
        : held;
  }
}

/// Actions qui font passer d'un état à un autre.
enum OrderAction {
  ship('Marquer comme expédiée'),
  confirm('Confirmer la réception'),
  cancel('Annuler la commande'),
  dispute('Signaler un problème'),
  refund('Rembourser l’acheteur'),
  release('Libérer les fonds au vendeur');

  final String label;
  const OrderAction(this.label);
}

/// Rôle de l'utilisateur vis-à-vis d'une commande.
enum OrderRole { buyer, seller, admin, none }

class OrderEscrow {
  OrderEscrow._();

  /// Délai de protection de l'acheteur après l'expédition : passé ce délai
  /// sans litige, les fonds sont libérés automatiquement.
  static const protectionDays = 14;

  /// Table des transitions : (état, action) → nouvel état.
  static const transitions = {
    (OrderState.held, OrderAction.ship): OrderState.shipped,
    (OrderState.held, OrderAction.cancel): OrderState.cancelled,
    (OrderState.shipped, OrderAction.confirm): OrderState.completed,
    (OrderState.shipped, OrderAction.dispute): OrderState.disputed,
    (OrderState.disputed, OrderAction.refund): OrderState.refunded,
    (OrderState.disputed, OrderAction.release): OrderState.completed,
  };

  /// Qui a le droit de déclencher chaque action.
  static const allowedRoles = {
    OrderAction.ship: {OrderRole.seller, OrderRole.admin},
    OrderAction.confirm: {OrderRole.buyer, OrderRole.admin},
    OrderAction.cancel: {OrderRole.buyer, OrderRole.seller, OrderRole.admin},
    OrderAction.dispute: {OrderRole.buyer},
    OrderAction.refund: {OrderRole.admin},
    OrderAction.release: {OrderRole.admin},
  };

  /// Vendeurs concernés par une commande.
  static List<String> sellersOf(Map<String, Object?> order) => [
    for (final key in (order['sellerKeys'] as List? ?? const []))
      key.toString(),
  ];

  static OrderRole roleOf(Map<String, Object?> order, String accountKey) {
    if (Permissions.isAdmin) return OrderRole.admin;
    if (order['ownerKey'] == accountKey) return OrderRole.buyer;
    if (sellersOf(order).contains(accountKey)) return OrderRole.seller;
    return OrderRole.none;
  }

  /// Actions possibles pour cet utilisateur dans l'état actuel.
  static List<OrderAction> availableActions(
    Map<String, Object?> order,
    String accountKey,
  ) {
    final state = OrderState.of(order);
    final role = roleOf(order, accountKey);
    return [
      for (final action in OrderAction.values)
        if (transitions.containsKey((state, action)) &&
            allowedRoles[action]!.contains(role))
          action,
    ];
  }

  /// Applique une action. Lève une [RuleException] si la transition est
  /// interdite. Une annulation ou un remboursement remet le stock en vente.
  static Future<Map<String, Object?>> apply(
    int orderId,
    OrderAction action, {
    String note = '',
  }) async {
    final me = CrowdTechSession.accountKey ?? '';
    final order = await MarketplaceRepository.orders.byId(orderId);
    if (order == null) throw const RuleException('Commande introuvable.');
    final state = OrderState.of(order);
    final next = transitions[(state, action)];
    if (next == null) {
      throw RuleException('Action impossible : la commande est « $state ».');
    }
    if (!allowedRoles[action]!.contains(roleOf(order, me))) {
      throw const RuleException('Vous ne pouvez pas faire cette action.');
    }
    if (action == OrderAction.dispute && note.trim().length < 5) {
      throw const RuleException('Décrivez le problème (5 caractères).');
    }
    final updated = _withState(order, next, me, action.label, note);
    if (action == OrderAction.ship) {
      updated['shippedAt'] = DateTime.now().toIso8601String();
    }
    await MarketplaceRepository.orders.update(
      orderId,
      {...updated}..remove('id'),
    );
    if (next == OrderState.cancelled || next == OrderState.refunded) {
      await _restoreStock(order);
    }
    return updated;
  }

  static Map<String, Object?> _withState(
    Map<String, Object?> order,
    String state,
    String by,
    String label,
    String note,
  ) => {
    ...order,
    'status': state,
    'history': [
      ...(order['history'] as List? ?? const []),
      {
        'status': state,
        'action': label,
        'by': by,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        'at': DateTime.now().toIso8601String(),
      },
    ],
  };

  /// Remet en stock les quantités d'une commande annulée ou remboursée.
  static Future<void> _restoreStock(Map<String, Object?> order) async {
    final products = await MarketplaceRepository.products.all();
    for (final line in (order['items'] as List? ?? const [])) {
      if (line is! Map) continue;
      final product = products
          .where((row) => row['id'] == line['productId'])
          .firstOrNull;
      final stock = product?['stock'];
      final quantity = line['quantity'];
      if (product == null || stock is! num || quantity is! num) continue;
      await MarketplaceRepository.products.update(
        product['id']! as int,
        {...product, 'stock': stock.toInt() + quantity.toInt()}..remove('id'),
      );
    }
  }

  /// Libère automatiquement les fonds des commandes expédiées depuis plus
  /// de [protectionDays] jours sans litige. Retourne le nombre de commandes.
  static Future<int> autoRelease({DateTime? now}) async {
    final today = now ?? DateTime.now();
    var released = 0;
    for (final order in await MarketplaceRepository.orders.all()) {
      if (OrderState.of(order) != OrderState.shipped) continue;
      final shipped = DateTime.tryParse(order['shippedAt']?.toString() ?? '');
      final id = order['id'];
      if (shipped == null || id is! int) continue;
      if (today.difference(shipped).inDays < protectionDays) continue;
      final updated = _withState(
        order,
        OrderState.completed,
        'système',
        'Fonds libérés automatiquement',
        'Délai de protection de $protectionDays jours écoulé.',
      );
      await MarketplaceRepository.orders.update(id, {...updated}..remove('id'));
      released++;
    }
    return released;
  }
}
