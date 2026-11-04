// Web : SQLite est stocké dans le navigateur (IndexedDB).

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void initializeDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

/// Sur le Web, la base est désignée par son seul nom (pas de dossier).
Future<String> databaseDirectory() async => '';
