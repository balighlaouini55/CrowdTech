// Données du module Crowdfunding : projets, jetons, investissements et
// espace du projet (fonctionnalités, jalons, questions, actualités).

import 'package:crowdtech/core/database/collection_repository.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';

abstract final class FundingRepository {
  static const projects = CollectionRepository('funding');
  static const features = CollectionRepository('project_features');
  static const tokenPacks = CollectionRepository('token_packs');
  static const investments = CollectionRepository('investments');
  static const tokenListings = CollectionRepository('token_listings');
  static const milestones = CollectionRepository('milestones');
  static const questions = CollectionRepository('project_questions');
  static const updates = CollectionRepository('project_updates');
  static const favorites = CollectionRepository('favorites');
  static const investorProfiles = CollectionRepository('investor_profiles');
  static const referrals = CollectionRepository('referrals');
  static const simulations = CollectionRepository('simulations');
  static const exchangeRates = CollectionRepository('exchange_rates');

  /// Ajoute une ligne au journal des opérations.
  static Future<void> logActivity({
    required String module,
    required String action,
    String details = '',
  }) => CrowdTechDatabase.logActivity(
    module: module,
    action: action,
    details: details,
  );

  /// Enregistre un investissement et la collecte du projet dans une même
  /// transaction. Retourne 0 si le projet est introuvable.
  static Future<int> saveInvestment({
    required int projectId,
    required Map<String, Object?> updatedProject,
    required Map<String, Object?> investment,
  }) => CrowdTechDatabase.saveInvestment(
    projectId: projectId,
    updatedProject: updatedProject,
    investment: investment,
  );
}
