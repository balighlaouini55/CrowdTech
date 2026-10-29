import 'database_factory_stub.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as platform;

void initializeDatabaseFactory() => platform.initializeDatabaseFactory();
