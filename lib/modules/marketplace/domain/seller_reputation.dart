// Algorithme d'évaluation de la réputation des vendeurs :
// - moyenne bayésienne des avis (un vendeur avec 1 seul avis 5★ ne passe
//   pas devant un vendeur avec 40 avis à 4,8★) ;
// - taux de commandes menées à bien (litiges et annulations pénalisent) ;
// - score final sur 100 et niveau (Nouveau, Bronze, Argent, Or, Top vendeur).

import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/modules/marketplace/data/marketplace_repository.dart';
import 'package:crowdtech/modules/marketplace/domain/order_escrow.dart';

class SellerReputation {
  final String sellerKey;
  final int reviewCount;
  final double averageStars;

  /// Moyenne bayésienne (ramenée vers [SellerReputationService.priorStars]
  /// quand il y a peu d'avis).
  final double weightedStars;
  final int completedOrders;
  final int problemOrders;

  /// Score de 0 à 100.
  final int score;
  final String level;
  final String emoji;

  const SellerReputation({
    required this.sellerKey,
    required this.reviewCount,
    required this.averageStars,
    required this.weightedStars,
    required this.completedOrders,
    required this.problemOrders,
    required this.score,
    required this.level,
    required this.emoji,
  });

  double get completionRate {
    final total = completedOrders + problemOrders;
    return total == 0 ? 1 : completedOrders / total;
  }
}

class SellerReputationService {
  SellerReputationService._();

  /// Note de départ supposée et son poids (en nombre d'avis fictifs).
  static const priorStars = 3.5;
  static const priorWeight = 3;

  /// Calcule la réputation à partir des avis et des commandes.
  static SellerReputation compute(
    String sellerKey,
    List<Map<String, Object?>> reviews,
    List<Map<String, Object?>> orders,
  ) {
    final mine = reviews.where((row) => row['sellerKey'] == sellerKey);
    final stars = [for (final row in mine) ?(row['stars'] as num?)?.toDouble()];
    final count = stars.length;
    final sum = stars.fold<double>(0, (total, value) => total + value);
    final average = count == 0 ? 0.0 : sum / count;
    final weighted = (sum + priorStars * priorWeight) / (count + priorWeight);

    var completed = 0;
    var problems = 0;
    for (final order in orders) {
      if (!OrderEscrow.sellersOf(order).contains(sellerKey)) continue;
      final state = OrderState.of(order);
      if (state == OrderState.completed) {
        // Un litige tranché en faveur du vendeur ne le pénalise pas.
        completed++;
      } else if (state == OrderState.refunded ||
          state == OrderState.disputed ||
          (state == OrderState.cancelled && _cancelledBySeller(order))) {
        problems++;
      }
    }
    final total = completed + problems;
    final completion = total == 0 ? 1.0 : completed / total;

    // 70 % la note, 30 % la fiabilité des commandes.
    final score = ((weighted - 1) / 4 * 70 + completion * 30).round().clamp(
      0,
      100,
    );
    final (level, emoji) = count == 0 && completed == 0
        ? ('Nouveau vendeur', '🌱')
        : score >= 85 && count >= 5
        ? ('Top vendeur', '🏆')
        : score >= 75
        ? ('Or', '🥇')
        : score >= 60
        ? ('Argent', '🥈')
        : ('Bronze', '🥉');
    return SellerReputation(
      sellerKey: sellerKey,
      reviewCount: count,
      averageStars: average,
      weightedStars: weighted,
      completedOrders: completed,
      problemOrders: problems,
      score: score,
      level: level,
      emoji: emoji,
    );
  }

  static bool _cancelledBySeller(Map<String, Object?> order) {
    final history = order['history'];
    if (history is! List || history.isEmpty) return false;
    final last = history.last;
    return last is Map &&
        OrderEscrow.sellersOf(order).contains(last['by']?.toString());
  }

  static Future<SellerReputation> load(String sellerKey) async => compute(
    sellerKey,
    await MarketplaceRepository.sellerReviews.all(),
    await MarketplaceRepository.orders.all(),
  );

  /// Avis reçus par un vendeur, du plus récent au plus ancien.
  static Future<List<Map<String, Object?>>> reviewsOf(String sellerKey) async =>
      (await MarketplaceRepository.sellerReviews.all())
          .where((row) => row['sellerKey'] == sellerKey)
          .toList()
          .reversed
          .toList();

  /// Avis de l'acheteur après une commande terminée (un par vendeur et
  /// par commande).
  static Future<void> review({
    required Map<String, Object?> order,
    required String sellerKey,
    required int stars,
    String comment = '',
  }) async {
    final me = CrowdTechSession.accountKey ?? '';
    if (order['ownerKey'] != me) {
      throw const RuleException('Seul l’acheteur peut noter le vendeur.');
    }
    if (!OrderEscrow.sellersOf(order).contains(sellerKey) || sellerKey == me) {
      throw const RuleException('Ce vendeur ne peut pas être noté ici.');
    }
    if (OrderState.of(order) != OrderState.completed) {
      throw const RuleException(
        'Vous pourrez noter le vendeur une fois la commande terminée.',
      );
    }
    if (stars < 1 || stars > 5) {
      throw const RuleException('Choisissez une note de 1 à 5 étoiles.');
    }
    final already = (await MarketplaceRepository.sellerReviews.all()).any(
      (row) => row['orderId'] == order['id'] && row['sellerKey'] == sellerKey,
    );
    if (already) {
      throw const RuleException('Vous avez déjà noté ce vendeur.');
    }
    await MarketplaceRepository.sellerReviews.add({
      'orderId': order['id'],
      'sellerKey': sellerKey,
      'ownerKey': me,
      'stars': stars,
      'comment': comment.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
