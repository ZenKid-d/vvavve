/// Фасад сервиса обновлений: на Android — скачивание и установка APK,
/// в браузере — заглушка (обновления приезжают деплоем статики).
library;

export 'update_service_web.dart' if (dart.library.io) 'update_service_io.dart';
