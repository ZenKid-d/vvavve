import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Части «Управления памятью», одинаковые на всех платформах.
///
/// Кэш изображений живёт в самих пакетах (flutter_cache_manager хранит его в
/// IndexedDB на вебе и в файлах на устройстве), поэтому его очистка платформы
/// не касается — в отличие от подсчёта размера, которому нужен доступ к файлам.
class StorageCommon {
  const StorageCommon._();

  /// Очищает кэш изображений (cached_network_image) и оперативный кэш.
  static Future<void> clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// Человекочитаемый размер: Б / КБ / МБ / ГБ.
  static String fmt(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    const units = ['КБ', 'МБ', 'ГБ', 'ТБ'];
    var size = bytes / 1024;
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[i]}';
  }
}
