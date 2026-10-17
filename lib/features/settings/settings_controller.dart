import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart' show AuthFailure;
import '../../core/io/file_io.dart';
import '../../core/providers.dart';
import '../../core/settings_controller.dart' show SettingsController;
import '../../core/update_controller.dart';
import '../../domain/models/source_type.dart';
import '../../sync/sync_service.dart' show SyncService, SyncState;

/// Тексты экрана настроек, вынесенные из виджетов.
///
/// Зачем отдельно: скоро настройки будут выглядеть по-разному в двух темах, но
/// формулировки у них общие. Пока строки живут прямо в `Text(...)`/`_Header(...)`,
/// каждая тема читает и правит свой набор, и они молча разъезжаются. Здесь
/// единственный источник правды: темы берут текст отсюда, различается вёрстка.
abstract final class SettingsCopy {
  // Заголовки секций (порядок секций задаёт экран).
  static const String sources = 'Источники';
  static const String yandex = 'Яндекс Музыка';
  static const String soundcloud = 'SoundCloud';
  static const String vk = 'VK Музыка';
  static const String network = 'Сеть';
  static const String audio = 'Аудио';
  static const String backup = 'Резервная копия';
  static const String lastfm = 'Last.fm';
  static const String update = 'Обновление';

  // Общие сообщения. Сетевые клиенты собираются один раз на старте, поэтому
  // и DoH, и прокси требуют перезапуска — говорим об этом одним текстом.
  static const String restartRequired =
      'Перезапустите приложение, чтобы применить';
  static const String proxyInvalid =
      'Неверный формат — ожидается host:port, напр. 127.0.0.1:1080';
  static const String backupImported = 'Библиотека импортирована';

  /// Качество потока: подписи чипов — тоже текст, который читают обе темы.
  static const List<String> qualityLabels = ['Низкое', 'Среднее', 'Высокое'];

  /// Подсказка под названием источника: что нужно, чтобы он заработал.
  static String sourceHint(SourceType s) => switch (s) {
        SourceType.youtube => 'Играет внутри приложения. Ключи не нужны.',
        SourceType.soundcloud =>
          'Играет внутри. Go+ — по токену твоей подписки.',
        SourceType.yandex => 'Играет внутри. Нужен токен аккаунта (риск бана).',
        SourceType.vk =>
          'Играет внутри. Нужен токен клиента VK с доступом к аудио (риск бана).',
        SourceType.local =>
          'Аудио-файлы с устройства (Music/Download). Права запросятся при первом скане.',
      };
}

/// Что делает плитка обновления прямо сейчас.
enum UpdateAction { check, install, none }

/// Строки и действие плитки обновления. Экран только рисует — все варианты
/// (скачано / качается / ждём проверки) решаются здесь, иначе «качает 40%»
/// пришлось бы собирать из трёх полей контроллера прямо в вёрстке.
class UpdateTile {
  const UpdateTile({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;

  /// [UpdateAction.none] — идёт проверка или скачивание, тап недоступен.
  final UpdateAction action;

  bool get busy => action == UpdateAction.none;
}

/// Единая точка правды для плитки обновления.
UpdateTile updateTile(UpdateController ctl) {
  final version = ctl.info?.version ?? '';

  // Скачано — предлагаем установить.
  if (ctl.isReady) {
    return UpdateTile(
      title: 'Установить обновление $version',
      subtitle: 'Файл скачан — можно установить в любой момент',
      action: UpdateAction.install,
    );
  }

  // Идёт фоновая загрузка.
  if (ctl.isDownloading) {
    final pct = (ctl.progress * 100).round();
    return UpdateTile(
      title: 'Загрузка обновления $version…',
      subtitle: '$pct% · продолжается в фоне',
      action: UpdateAction.none,
    );
  }

  final checking = ctl.stage == UpdateStage.checking;
  return UpdateTile(
    title: 'Проверить обновления',
    subtitle: 'Загрузка новой версии прямо из приложения',
    action: checking ? UpdateAction.none : UpdateAction.check,
  );
}

/// Честный статус вместо вечного «синхронизация включена»: если облако
/// недоступно (а в России это регулярно), пользователь должен видеть это,
/// а не гадать, почему лайки не доехали.
abstract final class SyncStatusLabel {
  static String of(SyncState state, DateTime? lastSyncAt) => switch (state) {
        SyncState.syncing => 'Синхронизация…',
        SyncState.error => 'Облако недоступно — данные сохраняются на устройстве',
        SyncState.idle => lastSyncAt == null
            ? 'Синхронизировано'
            : 'Синхронизировано в ${lastSyncAt.hour}:'
                '${lastSyncAt.minute.toString().padLeft(2, '0')}',
        SyncState.off => 'Синхронизация не запущена',
      };
}

/// Данные формы входа Last.fm. Отдельный объект вместо четырёх строк в
/// аргументах метода: `saveCredentials(key, secret)` и `login(user, pass)`
/// рядом легко перепутать местами, а это тихая поломка входа.
class LastfmCredentials {
  const LastfmCredentials({
    required this.apiKey,
    required this.secret,
    required this.login,
    required this.password,
  });

  final String apiKey;
  final String secret;
  final String login;
  final String password;
}

/// Проверка ввода прокси. Саму нормализацию делает [SettingsController] — он
/// же сохраняет значение; здесь тот же ответ для UI и для тестов.
abstract final class ProxyInput {
  /// Приведённый к `host:port` ввод либо null, если это не прокси.
  static String? normalize(String? value) =>
      SettingsController.normalizeProxy(value);

  static bool isValid(String? value) => normalize(value) != null;
}

/// Что вышло из нажатия «Применить» в поле прокси.
enum ProxyApply { applied, cleared, invalid }

/// Итог операции с резервной копией: [message] — что показать в снекбаре,
/// null — показывать нечего (пользователь отменил выбор файла либо всё прошло
/// так, что отдельного сообщения не нужно).
class BackupOutcome {
  const BackupOutcome([this.message]);

  /// Ошибка в терминах пользователя, а не в терминах стектрейса.
  const BackupOutcome.failed(String what, Object e) : message = '$what: $e';

  final String? message;
}

/// Качество потока. Явный выбор важнее старого флага `data_saver`: он остался
/// только для миграции старых установок.
int resolveStreamQuality({int? saved, bool? legacyDataSaver}) =>
    saved ?? ((legacyDataSaver ?? false) ? 0 : 2);

/// Логика экрана настроек: прокси, бэкап, аккаунт, Last.fm, обновление.
///
/// Виджеты остаются тонкими: спрашивают ввод, показывают то, что вернул
/// контроллер, и рисуют. Всё, что ходит в сеть/файлы/хранилища, живёт здесь —
/// при смене оформления правится только вёрстка, а поведение остаётся общим
/// для всех тем.
class SettingsActions {
  SettingsActions(this._ref);

  final WidgetRef _ref;

  // ------------------------------------------------------------ HTTP-прокси

  /// Задан ли прокси (для иконки и подписи состояния).
  bool get proxyActive => _ref.read(settingsProvider).httpProxy.isNotEmpty;

  /// Сохраняет прокси. Пустая строка — сброс. Возвращает, что получилось:
  /// различать «сбросили» и «применили» UI не нужно, а «неверный формат» —
  /// нужно (иначе кривой PROXY молча сломает всю сеть после перезапуска).
  Future<ProxyApply> applyHttpProxy(String value) async {
    final raw = value.trim();
    final ok = await _ref.read(settingsProvider).setHttpProxy(raw);
    if (!ok) return ProxyApply.invalid;
    return raw.isEmpty ? ProxyApply.cleared : ProxyApply.applied;
  }

  // ------------------------------------------------------- Резервная копия

  /// Отдаёт библиотеку в JSON через системное «Поделиться».
  Future<BackupOutcome> exportBackup() async {
    try {
      final data = _ref.read(libraryProvider).exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await shareTextFile(json,
          filename: 'roundds_backup.json',
          mime: 'application/json',
          text: 'vvavve — резервная копия библиотеки');
      return const BackupOutcome();
    } catch (e) {
      return BackupOutcome.failed('Ошибка экспорта', e);
    }
  }

  /// Выбирает JSON-файл и вливает его в библиотеку.
  Future<BackupOutcome> importBackup() async {
    final content = await pickJsonText();
    if (content == null) return const BackupOutcome(); // отмена выбора
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      await _ref.read(libraryProvider).importData(data);
      return const BackupOutcome(SettingsCopy.backupImported);
    } catch (e) {
      return BackupOutcome.failed('Ошибка импорта', e);
    }
  }

  // ------------------------------------------------------------- Аккаунт

  /// Статус обмена с облаком для строки аккаунта.
  String syncLabel(SyncService sync) =>
      SyncStatusLabel.of(sync.state, sync.lastSyncAt);

  /// Вход, если гость, выход — если вошёл. null — всё прошло; строка — текст
  /// ошибки для снекбара (сам бросать нельзя: тап по строке не должен ронять
  /// дерево виджетов).
  Future<String?> toggleAccount() async {
    try {
      final user = _ref.read(authStateProvider).value;
      if (user == null) {
        await _ref.read(authServiceProvider).signIn();
      } else {
        await _ref.read(authServiceProvider).signOut();
      }
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'Не удалось: $e';
    }
  }

  // --------------------------------------------------------------- Last.fm

  /// Вход в Last.fm. null — вошли; строка — что показать под полями.
  Future<String?> lastfmSignIn(LastfmCredentials c) async {
    final svc = _ref.read(lastfmServiceProvider);
    await svc.saveCredentials(c.apiKey, c.secret);
    final ok = await svc.login(c.login, c.password);
    return ok ? null : 'Не удалось войти — проверьте ключ/логин/пароль';
  }

  /// Выход из Last.fm (сессионный ключ удаляется, пароль и не хранился).
  Future<void> lastfmSignOut() => _ref.read(lastfmServiceProvider).logout();

  // -------------------------------------------------------- Прочее (сеть/аудио)

  /// Перевыпуск client_id SoundCloud. Возвращает строку статуса для поля:
  /// сам service_id добывается автоматически, кнопка — аварийный сценарий.
  Future<String> refreshSoundcloudClientId() async {
    try {
      final id = await _ref.read(soundcloudSourceProvider).refreshClientId();
      await _ref.read(prefsProvider).setString('sc_client_id', id);
      return 'Обновлён ✓';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  /// Качество потока и загрузок, как его видит экран.
  int get streamQuality {
    final prefs = _ref.read(prefsProvider);
    return resolveStreamQuality(
      saved: prefs.getInt('stream_quality'),
      legacyDataSaver: prefs.getBool('data_saver'),
    );
  }

  void setStreamQuality(int q) {
    _ref.read(prefsProvider).setInt('stream_quality', q);
    _ref.read(youtubeSourceProvider).streamQuality = q;
  }

  bool get autoDownloadLikes =>
      _ref.read(prefsProvider).getBool('autodl_likes') ?? false;

  void setAutoDownloadLikes(bool on) =>
      _ref.read(prefsProvider).setBool('autodl_likes', on);
}
