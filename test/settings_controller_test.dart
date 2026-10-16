import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roundds/core/update_controller.dart';
import 'package:roundds/core/update_service.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/features/settings/settings_controller.dart';
import 'package:roundds/sync/sync_service.dart' show SyncState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProxyInput — формат host:port', () {
    test('принимает обычный прокси и отдаёт его без изменений', () {
      expect(ProxyInput.normalize('127.0.0.1:1080'), '127.0.0.1:1080');
      expect(ProxyInput.isValid('127.0.0.1:1080'), isTrue);
    });

    test('срезает схему и путь — пользователь вставил ссылку', () {
      expect(ProxyInput.normalize('http://127.0.0.1:8080/'),
          '127.0.0.1:8080');
      expect(ProxyInput.normalize('socks5://10.0.0.1:1080'),
          '10.0.0.1:1080');
    });

    test('режет пробелы по краям (поле не должно ловить автозамену)', () {
      expect(ProxyInput.normalize('  127.0.0.1:1080 '), '127.0.0.1:1080');
    });

    test('без порта, с мусорным портом или с логином — не прокси', () {
      expect(ProxyInput.normalize('127.0.0.1'), isNull);
      expect(ProxyInput.normalize('127.0.0.1:port'), isNull);
      expect(ProxyInput.normalize('user:pass@127.0.0.1:8080'), isNull);
      expect(ProxyInput.isValid('localhost'), isFalse);
    });

    test('порт вне 1..65535 отвергаем — иначе сеть молча сломается', () {
      expect(ProxyInput.normalize('127.0.0.1:0'), isNull);
      expect(ProxyInput.normalize('127.0.0.1:65536'), isNull);
      expect(ProxyInput.normalize('127.0.0.1:65535'), '127.0.0.1:65535');
    });

    test('пусто — значит «прямое соединение», а не ошибка ввода', () {
      expect(ProxyInput.normalize(''), isNull);
      expect(ProxyInput.normalize(null), isNull);
      expect(ProxyInput.normalize('   '), isNull);
    });
  });

  group('SyncStatusLabel — честный статус синхронизации', () {
    test('идёт синхронизация', () {
      expect(SyncStatusLabel.of(SyncState.syncing, null), 'Синхронизация…');
    });

    test('облако недоступно — говорим честно, а не «всё хорошо»', () {
      expect(SyncStatusLabel.of(SyncState.error, null),
          'Облако недоступно — данные сохраняются на устройстве');
    });

    test('синхронизация выключена', () {
      expect(SyncStatusLabel.of(SyncState.off, null), 'Синхронизация не запущена');
    });

    test('простоя без метки времени — просто «синхронизировано»', () {
      expect(SyncStatusLabel.of(SyncState.idle, null), 'Синхронизировано');
    });

    test('с меткой времени — часы:минуты с ведущим нулём', () {
      expect(SyncStatusLabel.of(SyncState.idle, DateTime(2026, 5, 1, 9, 5)),
          'Синхронизировано в 9:05');
      expect(SyncStatusLabel.of(SyncState.idle, DateTime(2026, 5, 1, 23, 0)),
          'Синхронизировано в 23:00');
      expect(SyncStatusLabel.of(SyncState.idle, DateTime(2026, 5, 1, 0, 7)),
          'Синхронизировано в 0:07');
    });
  });

  group('resolveStreamQuality — качество звука', () {
    test('явный выбор важнее старого флага data_saver', () {
      expect(resolveStreamQuality(saved: 1, legacyDataSaver: true), 1);
      expect(resolveStreamQuality(saved: 0, legacyDataSaver: false), 0);
    });

    test('без явного выбора — по флагу data_saver', () {
      expect(resolveStreamQuality(legacyDataSaver: true), 0);
      expect(resolveStreamQuality(legacyDataSaver: false), 2);
    });

    test('совсем новый пользователь — высокое качество', () {
      expect(resolveStreamQuality(), 2);
    });
  });

  group('updateTile — плитка обновления', () {
    UpdateController ctlWith(UpdateStage stage,
            {String? version, double progress = 0, String? filePath}) =>
        UpdateController(UpdateService(Dio()))
          ..stage = stage
          ..info = version == null
              ? null
              : UpdateInfo(version: version, notes: '', apkUrl: '')
          ..progress = progress
          ..filePath = filePath;

    test('скачано — предлагаем установить и знаем версию', () {
      final tile =
          updateTile(ctlWith(UpdateStage.ready, version: '1.2.3', filePath: '/a.apk'));
      expect(tile.action, UpdateAction.install);
      expect(tile.title, 'Установить обновление 1.2.3');
      expect(tile.subtitle, 'Файл скачан — можно установить в любой момент');
      expect(tile.busy, isFalse);
    });

    test('качается — прогресс процентами, тап недоступен', () {
      final tile =
          updateTile(ctlWith(UpdateStage.downloading, version: '1.2.3', progress: 0.456));
      expect(tile.action, UpdateAction.none);
      expect(tile.busy, isTrue);
      expect(tile.title, 'Загрузка обновления 1.2.3…');
      expect(tile.subtitle, '46% · продолжается в фоне');
    });

    test('идёт проверка — кнопка есть, но нажать нельзя', () {
      final tile = updateTile(ctlWith(UpdateStage.checking));
      expect(tile.action, UpdateAction.none);
      expect(tile.title, 'Проверить обновления');
      expect(tile.subtitle, 'Загрузка новой версии прямо из приложения');
    });

    test('обновление есть, но не начато качать — можно жать', () {
      expect(updateTile(ctlWith(UpdateStage.available, version: '9.9.9')).action,
          UpdateAction.check);
    });

    test('без версии в подписи не остаётся висячего пробела', () {
      final tile = updateTile(ctlWith(UpdateStage.idle));
      expect(tile.title, 'Проверить обновления');
      expect(tile.action, UpdateAction.check);
    });
  });

  group('BackupOutcome — что показать после операции с бэкапом', () {
    test('успех/отмена — сообщения нет', () {
      expect(const BackupOutcome().message, isNull);
    });

    test('ошибка — текст пользователю, а не стектрейс', () {
      expect(const BackupOutcome.failed('Ошибка импорта', 'битый json').message,
          'Ошибка импорта: битый json');
    });
  });

  group('SettingsCopy — общие тексты', () {
    test('для каждого источника есть своя подсказка', () {
      for (final s in SourceType.values) {
        expect(SettingsCopy.sourceHint(s), isNotEmpty);
      }
    });

    test('подписи качества — по одной на чип', () {
      expect(SettingsCopy.qualityLabels.length, 3);
      expect(SettingsCopy.qualityLabels.first, 'Низкое');
    });

    test('заголовки секций не пустые и не совпадают', () {
      final headers = [
        SettingsCopy.sources,
        SettingsCopy.yandex,
        SettingsCopy.soundcloud,
        SettingsCopy.vk,
        SettingsCopy.network,
        SettingsCopy.audio,
        SettingsCopy.backup,
        SettingsCopy.lastfm,
        SettingsCopy.update,
      ];
      expect(headers.toSet().length, headers.length);
      expect(headers.every((h) => h.isNotEmpty), isTrue);
    });
  });
}
