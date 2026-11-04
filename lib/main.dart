// Point d'entrée de l'application : lance CrowdTechApp.

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/core/firebase/firebase_sync.dart';
import 'package:crowdtech/core/notifications/system_notifications.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Copie vers Firestore si config.json est fourni (sinon mode local).
  FirebaseSync.install();
  // Rappels d'événements programmés sur l'appareil (gratuit, sans serveur).
  await SystemNotifications.init();
  runApp(const CrowdTechApp());
}
