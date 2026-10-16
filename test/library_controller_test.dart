import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roundds/core/library_controller.dart';
import 'package:roundds/domain/models/album_result.dart';
import 'package:roundds/domain/models/playlist.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
// Логика экрана медиатеки (чистые функции — без виджетов и сети). Живёт в том же
// файле, потому что проверяет одно и то же хранилище: сортировка/умные
// подборки берут данные ровно из core/LibraryController.
import 'package:roundds/features/library/library_controller.dart';

Track _t(String id, String artist, {String title = 'T'}) => Track(
      id: id,
      title: title,
      artist: artist,
      source: SourceType.youtube,
    );

Future<LibraryController> _controller([Map<String, Object>? initial]) async {
  SharedPreferences.setMockInitialValues(initial ?? {});
  final prefs = await SharedPreferences.getInstance();
  return LibraryController(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryController — безопасные операции с несуществующим id', () {
    test('renamePlaylist на удалённый id — no-op, не бросает', () async {
      final lib = await _controller();
      await expectLater(lib.renamePlaylist('missing', 'X'), completes);
    });

    test('addToPlaylist на удалённый id — no-op, не бросает', () async {
      final lib = await _controller();
      await expectLater(
        lib.addToPlaylist('missing', _t('1', 'A')),
        completes,
      );
    });

    test('removeFromPlaylist на удалённый id — no-op, не бросает', () async {
      final lib = await _controller();
      await expectLater(
        lib.removeFromPlaylist('missing', _t('1', 'A')),
        completes,
      );
    });

    test('removeDuplicates на удалённый id — возвращает 0', () async {
      final lib = await _controller();
      expect(await lib.removeDuplicates('missing'), 0);
    });
  });

  group('LibraryController.removeDuplicates', () {
    test('убирает дубликаты по uid', () async {
      final lib = await _controller();
      final pl = await lib.createPlaylist('P');
      final track = _t('1', 'A');
      await lib.addToPlaylist(pl.id, track);
      // addToPlaylist сам не дублирует по uid — добавим второй раз тем же
      // объектом напрямую в список, минуя защиту, чтобы проверить чистку.
      pl.tracks.add(track);
      final removed = await lib.removeDuplicates(pl.id);
      expect(removed, 1);
      expect(pl.tracks.length, 1);
    });

    test('убирает дубликаты по «артист — название» даже с разным uid', () async {
      final lib = await _controller();
      final pl = await lib.createPlaylist('P');
      pl.tracks.add(_t('1', 'Artist', title: 'Song'));
      pl.tracks.add(_t('2', 'Artist', title: 'Song')); // другой id, тот же трек
      final removed = await lib.removeDuplicates(pl.id);
      expect(removed, 1);
      expect(pl.tracks.length, 1);
    });

    test('без дубликатов — возвращает 0', () async {
      final lib = await _controller();
      final pl = await lib.createPlaylist('P');
      await lib.addToPlaylist(pl.id, _t('1', 'A'));
      await lib.addToPlaylist(pl.id, _t('2', 'B'));
      expect(await lib.removeDuplicates(pl.id), 0);
      expect(pl.tracks.length, 2);
    });
  });

  group('LibraryController.topTracks — инвалидация кэша', () {
    test('новый pushHistory сбрасывает кэш топов', () async {
      final lib = await _controller();
      await lib.pushHistory(_t('1', 'A'));
      await lib.pushHistory(_t('1', 'A'));
      expect(lib.topTracks().first.value, 2);

      await lib.pushHistory(_t('1', 'A'));
      // Без инвалидации кэша здесь осталось бы значение 2.
      expect(lib.topTracks().first.value, 3);
    });

    test('importData со статистикой тоже сбрасывает кэш', () async {
      final lib = await _controller();
      await lib.pushHistory(_t('1', 'A'));
      expect(lib.topTracks().first.value, 1);

      await lib.importData({
        'stats': [
          {'track': _t('1', 'A').toJson(), 'count': 5},
        ],
      });
      expect(lib.topTracks().first.value, 6); // 1 + 5, счётчики суммируются
    });
  });

  group('LibraryController.importData — слияние и устойчивость к мусору', () {
    test('пропускает битые записи, не роняя весь импорт', () async {
      final lib = await _controller();
      await lib.importData({
        'liked': [
          _t('1', 'A').toJson(),
          {'title': 'no id'}, // битая запись — без id
          _t('2', 'B').toJson(),
        ],
      });
      expect(lib.liked.length, 2);
      expect(lib.liked.map((t) => t.id), containsAll(['1', '2']));
    });

    test('не дублирует уже существующие лайки/плейлисты по id', () async {
      final lib = await _controller();
      await lib.toggleLike(_t('1', 'A'));
      await lib.importData({
        'liked': [_t('1', 'A').toJson(), _t('2', 'B').toJson()],
      });
      expect(lib.liked.length, 2);
    });

    test('суммирует счётчики стата при повторном импорте', () async {
      final lib = await _controller();
      await lib.importData({
        'stats': [
          {'track': _t('1', 'A').toJson(), 'count': 3},
        ],
      });
      await lib.importData({
        'stats': [
          {'track': _t('1', 'A').toJson(), 'count': 2},
        ],
      });
      expect(lib.topTracks().first.value, 5);
    });
  });

  // --------------------------------------------------------------------------
  // Логика экрана медиатеки: features/library/library_controller.dart.
  // Только чистые функции — без виджетов, провайдеров и сети.
  // --------------------------------------------------------------------------

  group('playlistCreatedAt — момент создания из id', () {
    test('достаёт метку из id вида pl_<число>', () {
      expect(playlistCreatedAt('pl_1700000000000'), 1700000000000);
      expect(playlistCreatedAt('zz_pl_42_x'), 42);
    });

    test('на мусоре и на чужом формате — 0, а не исключение', () {
      expect(playlistCreatedAt('pl_'), 0);
      expect(playlistCreatedAt('playlist_1'), 0);
      expect(playlistCreatedAt(''), 0);
    });

    test('число не помещается в int — тоже 0, сортировка не падает', () {
      expect(playlistCreatedAt('pl_99999999999999999999999'), 0);
    });
  });

  group('sortPlaylists', () {
    PlaylistX pl(String id, String name, [int tracks = 0]) => PlaylistX(
          id: id,
          name: name,
          tracks: [for (var i = 0; i < tracks; i++) _t('$id-$i', 'A')],
        );

    test('по имени — без учёта регистра', () {
      final out = sortPlaylists(
        [pl('pl_1', 'яблоки'), pl('pl_2', 'Абрикос'), pl('pl_3', 'Вишня')],
        PlaylistSort.name,
      );
      expect(out.map((e) => e.name), ['Абрикос', 'Вишня', 'яблоки']);
    });

    test('по числу треков — от большего к меньшему', () {
      final out = sortPlaylists(
        [pl('pl_1', 'a', 1), pl('pl_2', 'b', 7), pl('pl_3', 'c', 3)],
        PlaylistSort.count,
      );
      expect(out.map((e) => e.name), ['b', 'c', 'a']);
    });

    test('по дате — сначала самые новые', () {
      final out = sortPlaylists(
        [pl('pl_100', 'старый'), pl('pl_300', 'новый'), pl('pl_200', 'средний')],
        PlaylistSort.recent,
      );
      expect(out.map((e) => e.name), ['новый', 'средний', 'старый']);
    });

    test('исходный список не переставляется (он из хранилища)', () {
      final src = [pl('pl_1', 'b'), pl('pl_2', 'a')];
      sortPlaylists(src, PlaylistSort.name);
      expect(src.map((e) => e.name), ['b', 'a']);
    });

    test('на каждый вариант сортировки есть подпись', () {
      expect(playlistSortLabels.keys.toSet(), PlaylistSort.values.toSet());
    });
  });

  group('matchTrack / matchAlbum — фильтр строки', () {
    final t = _t('1', 'Eminem', title: 'Lose Yourself');
    const a = AlbumResult(
      id: 'a1',
      title: 'The Marshall Mathers LP',
      artist: 'Eminem',
      source: SourceType.youtube,
    );

    test('пустой запрос совпадает со всем', () {
      expect(matchTrack(t, ''), isTrue);
      expect(matchAlbum(a, ''), isTrue);
    });

    test('ищет по названию и по артисту, регистр не важен', () {
      // Запрос приходит уже в нижнем регистре (так его кладёт поле поиска),
      // а вот поля трека/альбома приводит к нижнему регистру сам матчер.
      expect(matchTrack(t, 'lose'), isTrue);
      expect(matchTrack(t, 'eminem'), isTrue);
      expect(matchTrack(t, 'EMINEM'), isFalse); // регистр запроса — забота поля
      expect(matchTrack(t, 'drake'), isFalse);
      expect(matchAlbum(a, 'marshall'), isTrue);
      expect(matchAlbum(a, 'drake'), isFalse);
    });
  });

  group('parseTrackLines — список «Артист — Трек»', () {
    test('режет по строкам, срезает края, выкидывает пустые', () {
      expect(parseTrackLines('  Eminem — Lose Yourself \n\nThe Weeknd — X\r\n'),
          ['Eminem — Lose Yourself', 'The Weeknd — X']);
    });

    test('пустая строка и одни переводы строк — пустой список', () {
      expect(parseTrackLines(''), isEmpty);
      expect(parseTrackLines('\n \n'), isEmpty);
    });
  });

  group('buildSmartPlaylists — подборки, которые собирает приложение', () {
    test('порядок и виды фиксированы, пустые отсекает вызывающий', () async {
      final lib = await _controller();
      await lib.toggleLike(_t('1', 'Eminem'));
      await lib.pushHistory(_t('2', 'Portishead'));

      final all = buildSmartPlaylists(lib, '');
      expect(all.map((s) => s.kind),
          [SmartPlaylistKind.top, SmartPlaylistKind.recent, SmartPlaylistKind.liked]);
      expect(all.map((s) => s.title),
          ['Часто слушаю', 'Недавнее', 'Только лайки']);
      expect(all.last.tracks.map((t) => t.id), ['1']);
      expect(all[1].tracks.map((t) => t.id), ['2']);
    });

    test('поиск по названию оставляет только совпавшие подборки', () async {
      final lib = await _controller();
      await lib.toggleLike(_t('1', 'Eminem'));

      expect(buildSmartPlaylists(lib, 'лайк').map((s) => s.title),
          ['Только лайки']);
      expect(buildSmartPlaylists(lib, 'неттакого'), isEmpty);
    });
  });

  group('libraryTabs / LibraryTab', () {
    test('заголовков столько же, сколько вкладок (экран рисует по индексу)', () {
      expect(libraryTabs.length, LibraryTab.values.length);
    });
  });
}
