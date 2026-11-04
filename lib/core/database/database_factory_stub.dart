// Mobile (Android/iOS) : sqflite fonctionne sans configuration.
// Ordinateur (Windows, Linux, macOS) : SQLite via FFI, avec un seul fichier
// `crowdtech.db` dans le dossier de l'application de l'utilisateur
// (Windows : %APPDATA%\CrowdTech).

import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool get _isDesktop => Platform.isWindows || Platform.isLinux;

/// Les tests (`flutter test`) gardent le dossier temporaire de sqflite pour
/// ne jamais toucher la vraie base de l'utilisateur.
bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

void initializeDatabaseFactory() {
  if (_isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<String> databaseDirectory() async {
  if (!_isDesktop || _isTest) return getDatabasesPath();
  final home = Platform.isWindows
      ? Platform.environment['APPDATA']
      : Platform.environment['HOME'];
  if (home == null) return getDatabasesPath();
  final directory = Directory(
    join(home, Platform.isWindows ? 'CrowdTech' : '.crowdtech'),
  );
  await directory.create(recursive: true);
  return directory.path;
}
