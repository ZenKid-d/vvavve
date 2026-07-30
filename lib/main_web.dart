import 'package:audio_service/audio_service.dart';

import 'bootstrap.dart';

/// Точка входа веб-сборки: `flutter build web -t lib/main_web.dart`.
///
/// Отличия от Android — только в возможностях платформы:
/// • обходить блокировки нечем (соединение открывает браузер), эту роль берёт
///   на себя прокси-сервер;
/// • обновлений APK не существует — свежая версия приезжает деплоем статики;
/// • от фоновой службы остаётся MediaSession: настройки Android-канала
///   игнорируются, а воспроизведение живёт, пока открыта вкладка.
Future<void> main() => bootstrapApp(const PlatformCaps(
      networkBypass: false,
      apkUpdates: false,
      audioConfig: AudioServiceConfig(),
    ));
