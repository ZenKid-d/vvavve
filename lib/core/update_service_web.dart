import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'update_service_common.dart';

export 'update_service_common.dart' show UpdateInfo;

/// Веб-заглушка обновлений: обновлять нечего.
///
/// Приложение в браузере всегда свежее — новая версия приезжает обычным
/// деплоем статики. Скачивать и ставить APK здесь не только нечем (нет ни
/// файловой системы, ни системного установщика), но и незачем, поэтому
/// [check] всегда возвращает null и баннер обновления просто не появляется.
class UpdateService {
  UpdateService(this._dio);
  // ignore: unused_field — нужен для совпадения конструктора с io-версией
  final Dio _dio;

  /// Всегда null — на вебе обновлений не бывает.
  Future<UpdateInfo?> check() async => null;

  /// Версия сборки, прокинутая через `--dart-define=APP_VERSION=x.y.z`.
  /// package_info_plus на вебе отдаёт заглушку, поэтому берём из окружения.
  Future<String> currentVersion() async =>
      const String.fromEnvironment('APP_VERSION', defaultValue: 'web');

  Future<String> download(UpdateInfo info,
          {void Function(double)? onProgress}) async =>
      throw UnsupportedError('Обновление APK недоступно в браузере');

  Future<void> install(String path) async {}

  /// Нечего чистить: скачанных APK в браузере не бывает.
  Future<void> cleanupApks() async {}

  /// Строго ли `latest` новее `current` (semver major.minor.patch).
  @visibleForTesting
  static bool isNewer(String latest, String current) =>
      isVersionNewer(latest, current);
}
