import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_common.dart';

/// Утилиты для экрана «Управление памятью»: размеры и очистка кэша.
class Storage {
  const Storage._();

  /// Суммарный размер файлов в каталоге (рекурсивно), в байтах.
  static Future<int> dirSize(Directory d) async {
    if (!d.existsSync()) return 0;
    var total = 0;
    try {
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  /// Размер кэша приложения (обложки, временные файлы).
  static Future<int> cacheBytes() async =>
      dirSize(await getTemporaryDirectory());

  /// Очищает кэш изображений (cached_network_image) и оперативный кэш.
  static Future<void> clearCache() => StorageCommon.clearCache();

  /// Человекочитаемый размер: Б / КБ / МБ / ГБ.
  static String fmt(int bytes) => StorageCommon.fmt(bytes);
}
