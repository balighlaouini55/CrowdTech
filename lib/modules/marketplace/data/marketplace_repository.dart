// Données du module Marketplace : produits, paniers, commandes et avis
// sur les vendeurs.

import 'package:crowdtech/core/database/collection_repository.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';

abstract final class MarketplaceRepository {
  static const products = CollectionRepository('products');
  static const cart = CollectionRepository('cart');
  static const orders = CollectionRepository('orders');
  static const sellerReviews = CollectionRepository('seller_reviews');

  /// Enregistre la commande, baisse le stock et vide le panier de
  /// l'acheteur en une seule transaction.
  static Future<int> placeOrder(DataRow order) =>
      CrowdTechDatabase.createOrderAndClearCart(order);
}
