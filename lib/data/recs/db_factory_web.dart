import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite, собранный в wasm, с хранением в IndexedDB.
///
/// Нужен, чтобы `RecsStore` (полтора десятка мест с сырыми запросами) работал
/// в браузере без переписывания: тип `Database` здесь тот же самый, что отдаёт
/// нативный sqflite.
DatabaseFactory get dbFactory => databaseFactoryFfiWeb;

/// Фабрика сама подгружает sqlite3.wasm и поднимает воркер при первом открытии
/// БД, поэтому явная инициализация не нужна. Обязательное условие — файлы
/// `sqlite3.wasm` и `sqflite_sw.js` должны лежать в web/: их кладёт туда
/// `dart run sqflite_common_ffi_web:setup` (разовый шаг, описан в SETUP.md).
Future<void> initDbFactory() async {}
