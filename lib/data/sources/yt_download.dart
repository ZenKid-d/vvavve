/// Фасад нативной загрузки YouTube-потока в файл: на Android пишет файл,
/// в браузере всегда возвращает false.
library;

export 'yt_download_web.dart' if (dart.library.io) 'yt_download_io.dart';
