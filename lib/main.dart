import 'package:audio_service/audio_service.dart';

import 'bootstrap.dart';

/// Точка входа Android-сборки: доступен обход блокировок, самообновление APK
/// и настоящая фоновая служба с уведомлением.
Future<void> main() => bootstrapApp(const PlatformCaps(
      networkBypass: true,
      apkUpdates: true,
      audioConfig: AudioServiceConfig(
        androidNotificationChannelId: 'com.roundds.audio',
        androidNotificationChannelName: 'vvavve',
        androidNotificationOngoing: true,
      ),
    ));
