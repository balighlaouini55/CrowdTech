// Accès aux événements :
// - jauge maximale et file d'attente dynamique (promotion automatique quand
//   une place se libère) ;
// - badges d'accès cryptés et horodatés (AES-256-GCM) vérifiés au
//   contrôle des entrées ;
// - moteur de rappels automatiques (J-7, J-1, jour J) et notifications.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/core/errors/rule_exception.dart';
import 'package:crowdtech/core/notifications/system_notifications.dart';
import 'package:crowdtech/modules/events/data/events_repository.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart'
    show AEADParameters, AESEngine, GCMBlockCipher, KeyParameter;

/// Statuts d'une réservation et d'une inscription en file d'attente.
class ReservationStatus {
  ReservationStatus._();
  static const booked = 'Réservé';
  static const cancelled = 'Annulé';
  static const waiting = 'En attente';
  static const promoted = 'Promu';
  static const left = 'Retiré';

  static bool isActive(Map<String, Object?> reservation) =>
      reservation['status'] != cancelled;
}

// =============================================================================
// Badges d'accès signés

/// Résultat de la vérification d'un badge.
class BadgeCheck {
  final bool valid;
  final String message;
  final Map<String, Object?>? reservation;
  const BadgeCheck(this.valid, this.message, [this.reservation]);
}

class AccessBadge {
  AccessBadge._();

  /// Badge chiffré actuel.
  static const prefix = 'CTB2';

  /// Ancien badge seulement signé : toujours accepté au contrôle.
  static const legacyPrefix = 'CTB1';

  /// Phrase secrète des badges (à changer en production avec
  /// `--dart-define=BADGE_SECRET=...`).
  static const secret = String.fromEnvironment(
    'BADGE_SECRET',
    defaultValue: 'crowdtech-badge-secret-demo',
  );

  static String _unb64(String text) {
    final padded = text.padRight((text.length + 3) ~/ 4 * 4, '=');
    return utf8.decode(base64Url.decode(padded));
  }

  static String _sign(String payload) => Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode(payload)).toString().substring(0, 24);

  /// Fin de validité : le jour de l'événement à 23 h 59.
  static DateTime validUntil(String eventDate) {
    final day = parseFlexibleDate(eventDate) ?? DateTime.now();
    return DateTime(day.year, day.month, day.day, 23, 59, 59);
  }

  /// Clé AES de 256 bits déduite de la phrase secrète.
  static final _key = Uint8List.fromList(
    sha256.convert(utf8.encode(secret)).bytes,
  );

  /// AES-256-GCM : chiffre et détecte toute modification (tag de 128 bits).
  static GCMBlockCipher _cipher(bool encrypt, Uint8List nonce) =>
      GCMBlockCipher(AESEngine())..init(
        encrypt,
        AEADParameters(
          KeyParameter(_key),
          128,
          nonce,
          Uint8List.fromList(utf8.encode(prefix)),
        ),
      );

  static String _b64Bytes(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _bytesOf(String text) =>
      base64Url.decode(text.padRight((text.length + 3) ~/ 4 * 4, '='));

  /// Données en clair d'un badge authentique, sinon null.
  static String? _payloadOf(String badge) {
    final parts = badge.trim().split('.');
    if (parts.length != 3) return null;
    try {
      if (parts.first == legacyPrefix) {
        final payload = _unb64(parts[1]);
        final expected = _sign(payload);
        if (expected.length != parts[2].length) return null;
        // Comparaison à temps constant.
        var diff = 0;
        for (var i = 0; i < expected.length; i++) {
          diff |= expected.codeUnitAt(i) ^ parts[2].codeUnitAt(i);
        }
        return diff == 0 ? payload : null;
      }
      if (parts.first != prefix) return null;
      final nonce = _bytesOf(parts[1]);
      if (nonce.length != 12) return null;
      return utf8.decode(_cipher(false, nonce).process(_bytesOf(parts[2])));
    } on Exception {
      // Base64 invalide ou tag faux (InvalidCipherTextException).
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Crée un badge : `CTB2.<nonce>.<données chiffrées + tag>`. Les données
  /// contiennent le billet, l'événement, l'email du participant (empreinte),
  /// l'heure d'émission et la fin de validité ; illisibles sans la clé.
  static String issue({
    required String ticket,
    required int eventId,
    required String email,
    required String eventDate,
    DateTime? issuedAt,
  }) {
    final issued = issuedAt ?? DateTime.now();
    final emailHash = sha256
        .convert(utf8.encode(email.trim().toLowerCase()))
        .toString()
        .substring(0, 10);
    final payload = [
      ticket,
      eventId,
      emailHash,
      issued.millisecondsSinceEpoch ~/ 1000,
      validUntil(eventDate).millisecondsSinceEpoch ~/ 1000,
    ].join('|');
    final random = Random.secure();
    final nonce = Uint8List.fromList(
      List.generate(12, (_) => random.nextInt(256)),
    );
    final sealed = _cipher(true, nonce).process(utf8.encode(payload));
    return '$prefix.${_b64Bytes(nonce)}.${_b64Bytes(sealed)}';
  }

  /// Déchiffre les données d'un badge (null s'il n'est pas authentique).
  static ({String ticket, int eventId, DateTime issuedAt, DateTime validUntil})?
  decode(String badge) {
    final payload = _payloadOf(badge);
    if (payload == null) return null;
    try {
      final fields = payload.split('|');
      if (fields.length != 5) return null;
      return (
        ticket: fields[0],
        eventId: int.parse(fields[1]),
        issuedAt: DateTime.fromMillisecondsSinceEpoch(
          int.parse(fields[3]) * 1000,
        ),
        validUntil: DateTime.fromMillisecondsSinceEpoch(
          int.parse(fields[4]) * 1000,
        ),
      );
    } on FormatException {
      return null;
    }
  }

  /// Vrai si le badge a bien été émis avec la clé et n'a pas été modifié.
  static bool isAuthentic(String badge) => _payloadOf(badge) != null;

  /// Contrôle complet d'un badge (ou d'un ancien numéro de billet) et
  /// validation de l'entrée (une seule fois).
  static Future<BadgeCheck> checkIn(String code, {DateTime? now}) async {
    final input = code.trim();
    final reservations = await EventsRepository.reservations.all();
    Map<String, Object?>? reservation;
    if (input.startsWith('$prefix.') || input.startsWith('$legacyPrefix.')) {
      final data = decode(input);
      if (data == null) {
        return const BadgeCheck(
          false,
          'Badge falsifié : il n’a pas été émis par CrowdTech.',
        );
      }
      if ((now ?? DateTime.now()).isAfter(data.validUntil)) {
        return BadgeCheck(
          false,
          'Badge expiré depuis le ${formatDate(data.validUntil.toIso8601String())}.',
        );
      }
      reservation = reservations
          .where(
            (row) =>
                row['ticket'] == data.ticket &&
                (row['eventId'] as num?)?.toInt() == data.eventId,
          )
          .firstOrNull;
    } else {
      // Ancien billet sans badge : on vérifie le numéro.
      reservation = reservations
          .where((row) => row['ticket'] == input)
          .firstOrNull;
      // Le numéro saisi à la main expire comme le badge.
      final until = DateTime.tryParse(
        reservation?['validUntil']?.toString() ?? '',
      );
      if (until != null && (now ?? DateTime.now()).isAfter(until)) {
        return BadgeCheck(
          false,
          'Billet expiré depuis le ${formatDate(until.toIso8601String())}.',
        );
      }
    }
    if (reservation == null) {
      return const BadgeCheck(false, 'Pass introuvable dans la base locale.');
    }
    if (!ReservationStatus.isActive(reservation)) {
      return const BadgeCheck(false, 'Cette réservation a été annulée.');
    }
    if (reservation['checkedIn'] == true) {
      return const BadgeCheck(false, 'Ce pass a déjà été contrôlé.');
    }
    await EventsRepository.reservations.update(
      reservation['id']! as int,
      {
        ...reservation,
        'checkedIn': true,
        'checkedInAt': (now ?? DateTime.now()).toIso8601String(),
      }..remove('id'),
    );
    return BadgeCheck(
      true,
      'Entrée validée : ${reservation['attendeeName']}.',
      reservation,
    );
  }
}

// =============================================================================
// Jauge et file d'attente

class EventCapacity {
  EventCapacity._();

  static int _id(Object? value) => (value as num?)?.toInt() ?? -1;

  /// Réservations actives d'un événement.
  static Future<List<Map<String, Object?>>> activeReservations(
    int eventId,
  ) async => [
    for (final row in await EventsRepository.reservations.all())
      if (_id(row['eventId']) == eventId && ReservationStatus.isActive(row))
        row,
  ];

  /// File d'attente d'un événement, dans l'ordre d'inscription.
  static Future<List<Map<String, Object?>>> waitlist(int eventId) async => [
    for (final row in await EventsRepository.waitlist.all())
      if (_id(row['eventId']) == eventId &&
          row['status'] == ReservationStatus.waiting)
        row,
  ];

  /// Position (1, 2, 3…) d'un compte dans la file, ou null.
  static Future<int?> positionOf(int eventId, String accountKey) async {
    final queue = await waitlist(eventId);
    final index = queue.indexWhere((row) => row['ownerKey'] == accountKey);
    return index < 0 ? null : index + 1;
  }

  /// Crée une réservation avec son billet et son badge signé.
  static Future<Map<String, Object?>> book({
    required Map<String, Object?> event,
    required String accountKey,
    required String name,
    required String email,
  }) async {
    final eventId = event['id']! as int;
    final seats = (event['seats'] as num?)?.toInt() ?? 0;
    final active = await activeReservations(eventId);
    if (active.any((row) => row['ownerKey'] == accountKey)) {
      throw const RuleException('Vous avez déjà une place pour cet événement.');
    }
    if (active.length >= seats) {
      throw const RuleException(
        'Événement complet : inscrivez-vous sur la liste d’attente.',
      );
    }
    final now = DateTime.now();
    final ticket = 'CT-${now.microsecondsSinceEpoch}-${now.year}';
    final date = event['date']?.toString() ?? '';
    final payload = {
      'eventId': eventId,
      'eventTitle': event['title'],
      'attendeeName': name,
      'email': email,
      'ownerKey': accountKey,
      'ticket': ticket,
      'badge': AccessBadge.issue(
        ticket: ticket,
        eventId: eventId,
        email: email,
        eventDate: date,
        issuedAt: now,
      ),
      'issuedAt': now.toIso8601String(),
      'validUntil': AccessBadge.validUntil(date).toIso8601String(),
      'price': event['price'] ?? 0,
      'date': date,
      'checkedIn': false,
      'status': ReservationStatus.booked,
      'createdAt': now.toIso8601String(),
    };
    final id = await EventsRepository.reservations.add(payload);
    // Rappels programmés sur l'appareil (même application fermée).
    await SystemNotifications.scheduleForReservation(payload);
    return {'id': id, ...payload};
  }

  /// Inscription sur la liste d'attente d'un événement complet.
  /// Retourne la position obtenue.
  static Future<int> joinWaitlist({
    required Map<String, Object?> event,
    required String accountKey,
    required String name,
    required String email,
  }) async {
    final eventId = event['id']! as int;
    final reservations = await activeReservations(eventId);
    if (reservations.any((row) => row['ownerKey'] == accountKey)) {
      throw const RuleException('Vous avez déjà une place pour cet événement.');
    }
    final seats = (event['seats'] as num?)?.toInt() ?? 0;
    if (reservations.length < seats) {
      throw const RuleException('Il reste des places : réservez directement.');
    }
    final existing = await positionOf(eventId, accountKey);
    if (existing != null) return existing;
    await EventsRepository.waitlist.add({
      'eventId': eventId,
      'eventTitle': event['title'],
      'ownerKey': accountKey,
      'attendeeName': name,
      'email': email,
      'status': ReservationStatus.waiting,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return (await waitlist(eventId)).length;
  }

  static Future<void> leaveWaitlist(int eventId, String accountKey) async {
    for (final row in await waitlist(eventId)) {
      if (row['ownerKey'] != accountKey) continue;
      await EventsRepository.waitlist.update(
        row['id']! as int,
        {...row, 'status': ReservationStatus.left}..remove('id'),
      );
    }
  }

  /// Annule une réservation ; la première personne de la file d'attente
  /// reçoit automatiquement la place libérée (et une notification).
  /// Retourne le nom de la personne promue, ou null.
  static Future<String?> cancelReservation(int reservationId) async {
    final me = CrowdTechSession.accountKey;
    final reservation = await EventsRepository.reservations.byId(reservationId);
    if (reservation == null) {
      throw const RuleException('Réservation introuvable.');
    }
    if (reservation['ownerKey'] != me && !Permissions.isAdmin) {
      throw const RuleException('Ce billet ne vous appartient pas.');
    }
    if (!ReservationStatus.isActive(reservation)) {
      throw const RuleException('Réservation déjà annulée.');
    }
    if (reservation['checkedIn'] == true) {
      throw const RuleException('Billet déjà utilisé à l’entrée.');
    }
    await EventsRepository.reservations.update(
      reservationId,
      {
        ...reservation,
        'status': ReservationStatus.cancelled,
        'cancelledAt': DateTime.now().toIso8601String(),
      }..remove('id'),
    );
    await SystemNotifications.cancelForReservation(
      reservation['ticket']?.toString() ?? '',
    );
    return promoteNext(_id(reservation['eventId']));
  }

  /// Donne les places libres aux premiers de la file d'attente.
  static Future<String?> promoteNext(int eventId) async {
    final event = await EventsRepository.events.byId(eventId);
    if (event == null) return null;
    final queue = await waitlist(eventId);
    if (queue.isEmpty) return null;
    final seats = (event['seats'] as num?)?.toInt() ?? 0;
    if ((await activeReservations(eventId)).length >= seats) return null;
    final next = queue.first;
    final accountKey = next['ownerKey'].toString();
    final booked = await book(
      event: event,
      accountKey: accountKey,
      name: next['attendeeName']?.toString() ?? accountKey,
      email: next['email']?.toString() ?? accountKey,
    );
    await EventsRepository.waitlist.update(
      next['id']! as int,
      {
        ...next,
        'status': ReservationStatus.promoted,
        'ticket': booked['ticket'],
        'promotedAt': DateTime.now().toIso8601String(),
      }..remove('id'),
    );
    await Reminders.notify(
      accountKey: accountKey,
      key: 'promoted-${booked['id']}',
      title: '🎉 Une place s’est libérée !',
      body:
          'Vous passez de la liste d’attente à une place confirmée pour '
          '« ${event['title']} ». Votre billet est dans « Mes pass ».',
    );
    return next['attendeeName']?.toString();
  }
}

// =============================================================================
// Rappels et notifications

class Reminders {
  Reminders._();

  /// Rappels envoyés avant chaque événement réservé : (jours avant, texte).
  static const schedule = [
    (7, 'dans une semaine'),
    (1, 'demain'),
    (0, 'aujourd’hui'),
  ];

  /// Ajoute une notification (une seule fois par [key]).
  static Future<bool> notify({
    required String accountKey,
    required String key,
    required String title,
    required String body,
  }) async {
    final exists = (await EventsRepository.notifications.all()).any(
      (row) => row['key'] == key && row['ownerKey'] == accountKey,
    );
    if (exists) return false;
    await EventsRepository.notifications.add({
      'ownerKey': accountKey,
      'key': key,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    // Notification système immédiate (sauf rappels, déjà programmés).
    if (accountKey == CrowdTechSession.accountKey &&
        !key.startsWith('reminder-')) {
      await SystemNotifications.show(key, title, body);
    }
    return true;
  }

  /// Crée les rappels arrivés à échéance pour les billets de [accountKey].
  /// Retourne le nombre de nouveaux rappels.
  static Future<int> generate(String accountKey, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    var created = 0;
    for (final row in await EventsRepository.reservations.all()) {
      if (row['ownerKey'] != accountKey || !ReservationStatus.isActive(row)) {
        continue;
      }
      final date = parseFlexibleDate(row['date']?.toString());
      if (date == null) continue;
      final eventDay = DateTime(date.year, date.month, date.day);
      if (today.isAfter(eventDay.add(const Duration(days: 1)))) continue;
      for (final (days, label) in schedule) {
        final due = eventDay.subtract(Duration(days: days));
        if (today.isBefore(due)) continue;
        // Seul le rappel le plus proche est envoyé (pas J-7 le jour J).
        final nextDue = schedule
            .where((entry) => entry.$1 < days)
            .map((entry) => eventDay.subtract(Duration(days: entry.$1)))
            .where((other) => !today.isBefore(other));
        if (nextDue.isNotEmpty) continue;
        final added = await notify(
          accountKey: accountKey,
          key: 'reminder-${row['id']}-$days',
          title: '⏰ ${row['eventTitle']} $label',
          body:
              'N’oubliez pas votre événement du ${formatDate(row['date']?.toString())}. '
              'Votre badge d’accès est prêt dans « Mes pass ».',
        );
        if (added) created++;
      }
    }
    return created;
  }

  static Future<List<Map<String, Object?>>> of(String accountKey) async =>
      (await EventsRepository.notifications.ownedBy(accountKey)).reversed
          .toList();

  static Future<int> unreadCount(String accountKey) async =>
      (await of(accountKey)).where((row) => row['read'] != true).length;

  static Future<void> markAllRead(String accountKey) async {
    for (final row in await of(accountKey)) {
      if (row['read'] == true) continue;
      await EventsRepository.notifications.update(
        row['id']! as int,
        {...row, 'read': true}..remove('id'),
      );
    }
  }
}
