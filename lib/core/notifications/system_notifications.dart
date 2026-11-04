// Notifications système gratuites (sans serveur) : les rappels d'événements
// sont programmés sur l'appareil et s'affichent même application fermée.
// Remplace le push FCM, dont l'envoi exige un serveur payant (plan Blaze).
// Android, iOS, macOS, Windows et Linux ; ignoré sur le Web et dans les tests.

import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class SystemNotifications {
  SystemNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// true après une initialisation réussie (jamais dans les tests).
  static bool enabled = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'crowdtech_reminders',
      'Rappels d’événements',
      channelDescription: 'Rappels avant vos conférences et salons',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// À appeler au démarrage de l'application.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Ouvrir'),
          windows: WindowsInitializationSettings(
            appName: 'CrowdTech',
            appUserModelId: 'CrowdTech.App',
            guid: '5b2f8a64-3c1e-4d8a-9f61-2a7c0e9b4d13',
          ),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      enabled = true;
    } on Object catch (error) {
      debugPrint('Notifications système indisponibles : $error');
    }
  }

  /// Identifiant stable d'une notification à partir d'une clé texte.
  static int idFor(String key) => key.hashCode & 0x7fffffff;

  /// Affiche tout de suite une notification.
  static Future<void> show(String key, String title, String body) async {
    if (!enabled) return;
    try {
      await _plugin.show(
        id: idFor(key),
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } on Object catch (error) {
      debugPrint('Notification non affichée : $error');
    }
  }

  /// Heures des rappels d'un événement : J-7 et J-1 à 10 h, jour J à 8 h.
  static List<(String, DateTime, String)> reminderTimes(String eventDate) {
    final day = parseFlexibleDate(eventDate);
    if (day == null) return const [];
    return [
      (
        'j7',
        DateTime(day.year, day.month, day.day - 7, 10),
        'dans une semaine',
      ),
      ('j1', DateTime(day.year, day.month, day.day - 1, 10), 'demain'),
      ('j0', DateTime(day.year, day.month, day.day, 8), 'aujourd’hui'),
    ];
  }

  /// Programme les rappels d'un billet (ceux déjà passés sont ignorés).
  static Future<void> scheduleForReservation(
    Map<String, Object?> reservation,
  ) async {
    if (!enabled) return;
    final title = reservation['eventTitle']?.toString() ?? 'Événement';
    final now = DateTime.now();
    for (final (code, at, label) in reminderTimes(
      reservation['date']?.toString() ?? '',
    )) {
      if (!at.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: idFor('${reservation['ticket']}-$code'),
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _details,
          // Programmation « inexacte » : pas de permission d'alarme exacte.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: '⏰ $title $label',
          body: 'Votre badge d’accès est prêt dans CrowdTech → Mes pass.',
        );
      } on Object catch (error) {
        debugPrint('Rappel non programmé : $error');
      }
    }
  }

  /// Annule les rappels d'un billet annulé.
  static Future<void> cancelForReservation(String ticket) async {
    if (!enabled) return;
    for (final code in const ['j7', 'j1', 'j0']) {
      try {
        await _plugin.cancel(id: idFor('$ticket-$code'));
      } on Object {
        // Rappel déjà affiché ou inexistant.
      }
    }
  }
}
