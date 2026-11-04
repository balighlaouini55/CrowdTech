// Données du module Profil : profils et journal des opérations.

import 'package:crowdtech/core/database/collection_repository.dart';

abstract final class ProfileRepository {
  static const profiles = CollectionRepository('profiles');
  static const activityLog = CollectionRepository('activity_log');
}
