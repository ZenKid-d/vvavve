/// Фасад фабрики SQLite: нативный sqflite на мобильном, sqlite3-wasm в браузере.
/// Типы (`Database`, `DatabaseFactory`) в обоих случаях из sqflite_common —
/// поэтому код запросов в RecsStore платформы не замечает.
library;

export 'db_factory_web.dart' if (dart.library.io) 'db_factory_io.dart';
