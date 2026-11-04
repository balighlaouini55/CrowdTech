// Choisit la bonne implémentation SQLite selon la plateforme
// (mobile, ordinateur Windows/Linux/macOS ou Web).

import 'package:crowdtech/core/database/database_factory_stub.dart'
    if (dart.library.js_interop) 'package:crowdtech/core/database/database_factory_web.dart'
    as platform;

void initializeDatabaseFactory() => platform.initializeDatabaseFactory();

/// Dossier où se trouve le fichier `crowdtech.db` (hors Web).
Future<String> databaseDirectory() => platform.databaseDirectory();
