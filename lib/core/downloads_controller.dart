/// Фасад оффлайн-загрузок: на Android — настоящие файлы, в браузере — заглушка
/// с тем же публичным API (см. downloads_controller_web.dart).
library;

export 'downloads_controller_web.dart'
    if (dart.library.io) 'downloads_controller_io.dart';
