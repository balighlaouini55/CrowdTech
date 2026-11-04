// Modèle : une commande de la marketplace (CommandeProduit), avec ses lignes,
// son état de séquestre (Escrow) et son historique (collection `orders`).

import 'package:crowdtech/shared/utils/formatters.dart';

/// Une ligne de commande : produit, quantité et prix unitaire.
class OrderLine {
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? sellerKey;

  const OrderLine({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.sellerKey,
  });

  double get total => unitPrice * quantity;

  factory OrderLine.fromMap(Map<Object?, Object?> map) => OrderLine(
    productId: (map['productId'] as num?)?.toInt(),
    productName: map['productName']?.toString() ?? 'Produit',
    quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    sellerKey: map['sellerKey']?.toString(),
  );

  Map<String, Object?> toMap() => {
    'productId': ?productId,
    'productName': productName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'sellerKey': ?sellerKey,
  };
}

/// Une étape de l'historique d'une commande.
class OrderEvent {
  final String status;
  final String action;
  final String by;
  final String? note;
  final String? at;

  const OrderEvent({
    required this.status,
    required this.action,
    required this.by,
    this.note,
    this.at,
  });

  factory OrderEvent.fromMap(Map<Object?, Object?> map) => OrderEvent(
    status: map['status']?.toString() ?? '',
    action: map['action']?.toString() ?? '',
    by: map['by']?.toString() ?? '',
    note: map['note']?.toString(),
    at: map['at']?.toString(),
  );
}

class ProductOrder {
  final int? id;
  final String buyerKey;
  final String customerName;
  final String email;
  final String phone;
  final String address;
  final List<OrderLine> lines;
  final List<String> sellerKeys;
  final double total;
  final String status;
  final List<OrderEvent> history;
  final String? createdAt;
  final String? shippedAt;

  const ProductOrder({
    this.id,
    required this.buyerKey,
    this.customerName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.lines = const [],
    this.sellerKeys = const [],
    required this.total,
    required this.status,
    this.history = const [],
    this.createdAt,
    this.shippedAt,
  });

  /// Code affiché et encodé dans le QR code : « CMD-00042 ».
  String get code => 'CMD-${displayNumber(id)}';

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  factory ProductOrder.fromMap(Map<String, Object?> map) => ProductOrder(
    id: map['id'] as int?,
    buyerKey: map['ownerKey']?.toString() ?? '',
    customerName: map['customerName']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
    phone: map['phone']?.toString() ?? '',
    address: map['address']?.toString() ?? '',
    lines: [
      for (final line in (map['items'] as List? ?? const []))
        if (line is Map) OrderLine.fromMap(line),
    ],
    sellerKeys: [
      for (final key in (map['sellerKeys'] as List? ?? const []))
        key.toString(),
    ],
    total: (map['total'] as num?)?.toDouble() ?? 0,
    status: map['status']?.toString() ?? '',
    history: [
      for (final event in (map['history'] as List? ?? const []))
        if (event is Map) OrderEvent.fromMap(event),
    ],
    createdAt: map['createdAt']?.toString(),
    shippedAt: map['shippedAt']?.toString(),
  );
}
