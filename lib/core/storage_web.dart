import 'storage_common.dart';

/// Веб-вариант «Управления памятью».
///
/// Считать размер кэша нечем: файловой системы у страницы нет, а квоту
/// IndexedDB, куда flutter_cache_manager кладёт обложки, браузер наружу не
/// отдаёт. Поэтому размер — 0 (экран показывает прочерк), а очистка работает
/// как везде.
class Storage {
  const Storage._();

  /// Всегда 0: посчитать занятое место в браузере невозможно.
  static Future<int> cacheBytes() async => 0;

  /// Очищает кэш изображений (cached_network_image) и оперативный кэш.
  static Future<void> clearCache() => StorageCommon.clearCache();

  /// Человекочитаемый размер: Б / КБ / МБ / ГБ.
  static String fmt(int bytes) => StorageCommon.fmt(bytes);
}
