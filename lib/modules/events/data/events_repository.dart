// Données du module Événements : événements, billets, file d'attente et
// notifications.

import 'package:crowdtech/core/database/collection_repository.dart';

abstract final class EventsRepository {
  static const events = CollectionRepository('events');
  static const reservations = CollectionRepository('reservations');
  static const waitlist = CollectionRepository('waitlist');
  static const notifications = CollectionRepository('notifications');
}
