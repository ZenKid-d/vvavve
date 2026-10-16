import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

/// Штатная фабрика sqflite поверх нативного SQLite.
DatabaseFactory get dbFactory => sqflite.databaseFactory;

/// Нативному sqflite подготовка не нужна.
Future<void> initDbFactory() async {}
