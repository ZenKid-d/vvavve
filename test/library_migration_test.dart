import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roundds/core/library_controller.dart';
import 'package:roundds/domain/models/album_result.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';

/// Проверяем перенос данных пользователя со старого формата (голые списки в
/// JSON) на новый (записи с метками времени и надгробиями). Это единственное
/// место, где обновление приложения трогает уже существующие данные, поэтому
/// проверяется каждый ключ, а не «в целом работает».

Track _t(String id, String artist, {String title = 'T'}) => Track(
      id: id,
      title: title,
      artist: artist,
      source: SourceType.youtube,
    );

AlbumResult _a(String id, String title) => AlbumResult(
      id: id,
      title: title,
      artist: 'A',
      source: SourceType.youtube,
    );

Future<LibraryController> _controller(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return LibraryController(prefs);
}

/// Пересоздаёт контроллер на тех же prefs — так проверяется, что записанное
/// в новом формате читается обратно.
Future<LibraryController> _reopen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return LibraryController(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Миграция v1 → v2', () {
    test('лайки переносятся с сохранением порядка', () async {
      final lib = await _controller({
        'liked': jsonEncode([
          _t('1', 'Первый').toJson(),
          _t('2', 'Второй').toJson(),
          _t('3', 'Третий').toJson(),
        ]),
      });

      expect(lib.liked.map((t) => t.id), ['1', '2', '3']);
      expect(lib.isLiked(_t('2', 'Второй')), isTrue);
    });

    test('после миграции данные переживают перезапуск', () async {
      final lib = await _controller({
        'liked': jsonEncode([_t('1', 'A').toJson()]),
      });
      await lib.toggleLike(_t('9', 'Новый'));

      final again = await _reopen();
      expect(again.liked.map((t) => t.id).toSet(), {'1', '9'});
    });

    test('снятый лайк не воскресает после перезапуска', () async {
      final lib = await _controller({
        'liked': jsonEncode([_t('1', 'A').toJson(), _t('2', 'B').toJson()]),
      });
      await lib.toggleLike(_t('1', 'A')); // снимаем

      final again = await _reopen();
      expect(again.liked.map((t) => t.id), ['2']);
      // Именно ради этого случая нужны надгробия: в старом формате удаление
      // было неотличимо от «никогда не было».
      expect(again.isLiked(_t('1', 'A')), isFalse);
    });

    test('плейлисты переносятся вместе с треками', () async {
      final lib = await _controller({
        'playlists': jsonEncode([
          {
            'id': 'pl_1',
            'name': 'Мой',
            'tracks': [_t('1', 'A').toJson(), _t('2', 'B').toJson()],
          }
        ]),
      });

      expect(lib.playlists, hasLength(1));
      expect(lib.playlists.first.name, 'Мой');
      expect(lib.playlists.first.tracks, hasLength(2));

      await lib.renamePlaylist('pl_1', 'Переименован');
      final again = await _reopen();
      expect(again.playlists.first.name, 'Переименован');
    });

    test('удалённый плейлист не возвращается', () async {
      final lib = await _controller({
        'playlists': jsonEncode([
          {'id': 'pl_1', 'name': 'Мой', 'tracks': []}
        ]),
      });
      await lib.deletePlaylist('pl_1');

      final again = await _reopen();
      expect(again.playlists, isEmpty);
    });

    test('лайки и дизлайки альбомов', () async {
      final lib = await _controller({
        'liked_albums': jsonEncode([_a('al1', 'Люблю').toJson()]),
        'disliked_albums': jsonEncode([_a('al2', 'Не люблю').toJson()]),
      });

      expect(lib.likedAlbums.map((a) => a.id), ['al1']);
      expect(lib.dislikedAlbums.map((a) => a.id), ['al2']);
      expect(lib.isAlbumLiked(_a('al1', 'Люблю')), isTrue);
      expect(lib.isAlbumDisliked(_a('al2', 'Не люблю')), isTrue);
    });

    test('подписки и чёрный список сводятся в одну запись на артиста',
        () async {
      // В v1 это были два ключа: подписки с авторским регистром, чёрный список
      // в нижнем. Один и тот же артист мог оказаться в обоих.
      final lib = await _controller({
        'followed_artists': <String>['Arctic Monkeys', 'Кино'],
        'blacklist_artists': <String>['arctic monkeys', 'нежелательный'],
      });

      expect(lib.followedArtists, containsAll(['Arctic Monkeys', 'Кино']));
      expect(lib.isFollowing('arctic monkeys'), isTrue,
          reason: 'регистр не должен влиять');
      expect(lib.isArtistBlacklisted('Arctic Monkeys'), isTrue);
      expect(lib.blacklistedArtists, containsAll(['arctic monkeys', 'нежелательный']));

      // Снятие одного флага не трогает второй.
      await lib.unblacklistArtist('Arctic Monkeys');
      final again = await _reopen();
      expect(again.isArtistBlacklisted('Arctic Monkeys'), isFalse);
      expect(again.isFollowing('Arctic Monkeys'), isTrue);
    });

    test('счётчики прослушиваний переносятся и не задваиваются', () async {
      final lib = await _controller({
        'stats': jsonEncode([
          {'track': _t('1', 'A').toJson(), 'count': 5},
          {'track': _t('2', 'B').toJson(), 'count': 3},
        ]),
      });

      expect(lib.totalPlays, 8);
      expect(lib.uniqueTracks, 2);
      expect(lib.topTracks().first.value, 5);

      await lib.pushHistory(_t('1', 'A'));
      expect(lib.totalPlays, 9);

      // Перезапуск не должен ни потерять, ни удвоить счёт.
      final again = await _reopen();
      expect(again.totalPlays, 9);
    });

    test('время прослушивания переносится из старого ключа', () async {
      final lib = await _controller({'listened_ms': 123456});
      expect(lib.totalListened.inMilliseconds, 123456);

      await lib.addListened(1000);
      final again = await _reopen();
      expect(again.totalListened.inMilliseconds, 124456);
    });

    test('резервная копия старого значения сохраняется', () async {
      final v1 = jsonEncode([_t('1', 'A').toJson()]);
      await _controller({'liked': v1});

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString('liked__v1_backup'), v1,
          reason: 'без копии откатиться будет не к чему');
    });

    test('битые данные не обнуляют библиотеку, а поднимаются из копии',
        () async {
      final v1 = jsonEncode([_t('1', 'A').toJson(), _t('2', 'B').toJson()]);
      await _controller({'liked': v1});

      // Портим текущее значение, оставляя резервную копию нетронутой.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('liked', '{"v":2,"items":[{"сломано"');

      final again = await _reopen();
      expect(again.liked.map((t) => t.id), ['1', '2']);
    });

    test('экспорт остаётся в первом формате', () async {
      final lib = await _controller({
        'liked': jsonEncode([_t('1', 'A').toJson()]),
        'stats': jsonEncode([
          {'track': _t('1', 'A').toJson(), 'count': 4},
        ]),
      });

      final data = lib.exportData();
      expect(data['version'], 1);
      expect((data['liked'] as List), hasLength(1));
      // Наружу отдаём одно число, а не карту по устройствам: файл бэкапа
      // должны читать и старые сборки.
      expect((data['stats'] as List).first['count'], 4);
    });

    test('импорт из файла складывает счётчики, как и раньше', () async {
      final lib = await _controller({
        'stats': jsonEncode([
          {'track': _t('1', 'A').toJson(), 'count': 2},
        ]),
      });

      await lib.importData({
        'version': 1,
        'stats': [
          {'track': _t('1', 'A').toJson(), 'count': 3},
        ],
      });

      expect(lib.totalPlays, 5, reason: 'восстановление из файла — суммирует');
    });
  });
}
