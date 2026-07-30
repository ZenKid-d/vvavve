import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roundds/core/library_controller.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/sync/sync_service.dart';
import 'package:roundds/sync/sync_transport.dart';
import 'package:roundds/sync/synced_record.dart';

/// Транспорт «в памяти» вместо Firestore: один экземпляр играет роль облака,
/// к нему подключаются несколько устройств. Так проверяется именно логика
/// обмена, без сети и без эмулятора.
class FakeCloud {
  final Map<String, Map<String, SyncedRecord<Map<String, dynamic>>>> _data = {};
  final Map<String, int> _serverAt = {};
  final _controllers =
      <String, List<StreamController<List<RemoteDoc>>>>{};
  int _clock = 1;

  /// Данные разных аккаунтов не пересекаются — как и в настоящем хранилище,
  /// где всё лежит под users/{uid}.
  SyncTransport connect(String uid) => _FakeTransport(this, uid);

  void _push(String collection, List<SyncedRecord<Map<String, dynamic>>> records) {
    final col = _data.putIfAbsent(collection, () => {});
    final docs = <RemoteDoc>[];
    for (final r in records) {
      col[r.key] = r;
      final at = _clock++;
      _serverAt['$collection/${r.key}'] = at;
      docs.add(RemoteDoc(record: r, serverAt: at));
    }
    for (final c in _controllers[collection] ?? const []) {
      c.add(docs);
    }
  }

  List<RemoteDoc> _snapshot(String collection, int since) {
    final col = _data[collection] ?? const {};
    final out = <RemoteDoc>[];
    for (final r in col.values) {
      final at = _serverAt['$collection/${r.key}'] ?? 0;
      if (at > since) out.add(RemoteDoc(record: r, serverAt: at));
    }
    out.sort((a, b) => a.serverAt.compareTo(b.serverAt));
    return out;
  }
}

class _FakeTransport implements SyncTransport {
  _FakeTransport(this.cloud, this.uid);
  final FakeCloud cloud;
  final String uid;
  final _owned = <StreamController<List<RemoteDoc>>>[];

  String _path(String collection) => '$uid/$collection';

  @override
  Stream<List<RemoteDoc>> watch(String collection, {required int since}) {
    final c = StreamController<List<RemoteDoc>>.broadcast();
    _owned.add(c);
    cloud._controllers.putIfAbsent(_path(collection), () => []).add(c);
    scheduleMicrotask(() {
      final initial = cloud._snapshot(_path(collection), since);
      if (initial.isNotEmpty && !c.isClosed) c.add(initial);
    });
    return c.stream;
  }

  @override
  Future<void> push(
      String collection, List<SyncedRecord<Map<String, dynamic>>> records) async {
    cloud._push(_path(collection), records);
  }

  @override
  Future<void> dispose() async {
    for (final c in _owned) {
      for (final list in cloud._controllers.values) {
        list.remove(c);
      }
      await c.close();
    }
    _owned.clear();
  }
}

Track _t(String id, String artist) => Track(
      id: id,
      title: 'T$id',
      artist: artist,
      source: SourceType.youtube,
    );

/// Одно «устройство»: свои prefs, своя библиотека, своя служба обмена.
class _Device {
  _Device(this.library, this.sync);
  final LibraryController library;
  final SyncService sync;
}

Future<_Device> _device(FakeCloud cloud, String name,
    {Map<String, Object>? initial}) async {
  // SharedPreferences кэширует единственный экземпляр на изолят, поэтому без
  // сброса оба «устройства» работали бы с одним хранилищем — и обмен между
  // ними проверить было бы нечем.
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({
    ...?initial,
    // Разные идентификаторы установки — иначе счётчики окажутся общими.
    'device_id': name,
  });
  final prefs = await SharedPreferences.getInstance();
  final library = LibraryController(prefs);
  final sync = SyncService(
    prefs: prefs,
    library: library,
    transportFactory: cloud.connect,
    // В бою отправка копится две секунды; в тесте ждать столько незачем.
    pushDelay: const Duration(milliseconds: 10),
  );
  return _Device(library, sync);
}

/// Даёт отработать подпискам и отложенной отправке.
Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Обмен между устройствами', () {
    test('лайк уезжает в облако и приезжает на второе устройство', () async {
      final cloud = FakeCloud();

      final a = await _device(cloud, 'dev-a');
      await a.sync.start('user1');
      await a.library.toggleLike(_t('1', 'Артист'));
      await _settle();

      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user1');
      await _settle();

      expect(b.library.liked.map((t) => t.id), ['1']);
    });

    test('снятый лайк не воскресает на втором устройстве', () async {
      final cloud = FakeCloud();

      final a = await _device(cloud, 'dev-a');
      await a.sync.start('user1');
      await a.library.toggleLike(_t('1', 'Артист'));
      await _settle();

      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user1');
      await _settle();
      expect(b.library.liked, hasLength(1));

      // Снимаем на втором — первое должно узнать об этом.
      await b.library.toggleLike(_t('1', 'Артист'));
      await _settle();

      expect(a.library.liked, isEmpty,
          reason: 'ради этого случая и нужны надгробия');
    });

    test('счётчики прослушиваний складываются, но не задваиваются', () async {
      final cloud = FakeCloud();

      final a = await _device(cloud, 'dev-a');
      await a.sync.start('user1');
      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user1');

      for (var i = 0; i < 5; i++) {
        await a.library.pushHistory(_t('1', 'Артист'));
      }
      for (var i = 0; i < 3; i++) {
        await b.library.pushHistory(_t('1', 'Артист'));
      }
      await _settle();
      await _settle();

      expect(a.library.totalPlays, 8);
      expect(b.library.totalPlays, 8);

      // Повторный круг обмена ничего не меняет — счётчик сходится, а не растёт.
      await _settle();
      expect(a.library.totalPlays, 8);
      expect(b.library.totalPlays, 8);
    });

    test('плейлисты и артисты синхронизируются', () async {
      final cloud = FakeCloud();

      final a = await _device(cloud, 'dev-a');
      await a.sync.start('user1');
      final pl = await a.library.createPlaylist('Дорожный');
      await a.library.addToPlaylist(pl.id, _t('7', 'Кто-то'));
      await a.library.toggleFollow('Arctic Monkeys');
      await a.library.blacklistArtist('Нежелательный');
      await _settle();

      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user1');
      await _settle();

      expect(b.library.playlists.map((p) => p.name), ['Дорожный']);
      expect(b.library.playlists.first.tracks, hasLength(1));
      expect(b.library.isFollowing('arctic monkeys'), isTrue);
      expect(b.library.isArtistBlacklisted('нежелательный'), isTrue);
    });

    test('без входа обмен не происходит', () async {
      final cloud = FakeCloud();
      final a = await _device(cloud, 'dev-a');
      // start не вызывали — служба обязана молчать.
      await a.library.toggleLike(_t('1', 'Артист'));
      await _settle();

      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user1');
      await _settle();

      expect(b.library.liked, isEmpty);
      expect(a.sync.state, SyncState.off);
    });

    test('чужая библиотека не уезжает в новый аккаунт', () async {
      final cloud = FakeCloud();

      // Устройство уже синхронизировалось под user1.
      final a = await _device(cloud, 'dev-a');
      await a.sync.start('user1');
      await a.library.toggleLike(_t('личное', 'Первый хозяин'));
      await _settle();

      // Тем же устройством входит другой аккаунт.
      await a.sync.stop();
      await a.sync.start('user2');
      await _settle();

      // Смотрим со стороны второго аккаунта: там пусто.
      final b = await _device(cloud, 'dev-b');
      await b.sync.start('user2');
      await _settle();

      expect(b.library.liked, isEmpty,
          reason: 'иначе библиотека одного человека утекла бы другому');
      // При этом локально данные никуда не делись.
      expect(a.library.liked, hasLength(1));
    });
  });
}
