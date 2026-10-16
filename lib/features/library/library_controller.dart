import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod 3 вынес StateProvider в legacy-модуль (курс на Notifier) — см. пояснение
// в core/providers.dart. Здесь только два простых «значения настроек списка».
import 'package:flutter_riverpod/legacy.dart';

import '../../core/io/file_io.dart';
// Префикс: одноимённый класс хранилища библиотеки уже живёт в core, а здесь
// мы про него только читаем (для умных плейлистов).
import '../../core/library_controller.dart' as lib;
import '../../core/providers.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';

/// Строка фильтра медиатеки (по названию/артисту), в нижнем регистре.
final libraryQueryProvider = StateProvider<String>((ref) => '');

/// Порядок плейлистов в списке. Хранится провайдером, а не полем виджета:
/// выбор должен переживать пересборку и переключение вкладок.
final playlistSortProvider =
    StateProvider<PlaylistSort>((ref) => PlaylistSort.recent);

enum PlaylistSort { recent, name, count }

/// Подписи вариантов сортировки — общий текст для всех тем оформления,
/// поэтому хранится здесь, а не внутри PopupMenuButton.
const Map<PlaylistSort, String> playlistSortLabels = {
  PlaylistSort.recent: 'Недавно добавленные',
  PlaylistSort.name: 'По имени',
  PlaylistSort.count: 'По числу треков',
};

/// Вкладки медиатеки. Порядок значений совпадает с [libraryTabs]: экран
/// рисует заголовки по индексу, поэтому эти два списка меняются вместе.
enum LibraryTab { playlists, liked, downloads, queue }

const List<String> libraryTabs = [
  'Плейлисты',
  'Любимое',
  'Загрузки',
  'Очередь',
];

/// Откуда импортируем плейлист. Значение bottom-листа превращается в вызов
/// [LibraryActions] — строковые литералы в двух местах разъезжаются.
enum PlaylistImportSource { youtube, youtubeLikes, yandex, spotify, list, file }

/// Момент создания плейлиста зашит в его id (`pl_<миллисекунды>`). Отдельное
/// поле с датой не храним: id и так уникален, а разбирать его дешевле, чем
/// таскать лишний ключ в бэкапах.
int playlistCreatedAt(String id) {
  final m = RegExp(r'pl_(\d+)').firstMatch(id);
  return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
}

/// Копия списка, отсортированная по [sort]. Исходный список не трогаем — он
/// приходит из хранилища и переиспользуется другими экранами.
List<PlaylistX> sortPlaylists(List<PlaylistX> list, PlaylistSort sort) {
  final l = List<PlaylistX>.from(list);
  switch (sort) {
    case PlaylistSort.name:
      l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PlaylistSort.count:
      l.sort((a, b) => b.tracks.length - a.tracks.length);
    case PlaylistSort.recent:
      l.sort(
          (a, b) => playlistCreatedAt(b.id).compareTo(playlistCreatedAt(a.id)));
  }
  return l;
}

/// Совпадение трека с фильтром строки. [q] приходит уже в нижнем регистре.
bool matchTrack(Track t, String q) =>
    q.isEmpty ||
    t.title.toLowerCase().contains(q) ||
    t.artist.toLowerCase().contains(q);

/// То же для альбомов из «любимого» (у них нет треков, только название).
bool matchAlbum(AlbumResult a, String q) =>
    q.isEmpty ||
    a.title.toLowerCase().contains(q) ||
    a.artist.toLowerCase().contains(q);

/// Какая умная подборка перед нами. Иконку по этому виду выбирает уже экран —
/// здесь про данные, а не про картинки.
enum SmartPlaylistKind { top, recent, liked }

/// Подборка, которую приложение собирает само (не пользовательский плейлист).
class SmartPlaylist {
  const SmartPlaylist({
    required this.kind,
    required this.title,
    required this.tracks,
  });

  final SmartPlaylistKind kind;
  final String title;
  final List<Track> tracks;
}

/// Умные подборки, отфильтрованные строкой поиска. Пустые отсекает вызывающий:
/// показывать «Только лайки: 0 треков» незачем.
List<SmartPlaylist> buildSmartPlaylists(lib.LibraryController lib, String q) =>
    [
      SmartPlaylist(
        kind: SmartPlaylistKind.top,
        title: 'Часто слушаю',
        tracks: lib.topTracks(limit: 50).map((e) => e.key).toList(),
      ),
      SmartPlaylist(
        kind: SmartPlaylistKind.recent,
        title: 'Недавнее',
        tracks: lib.history,
      ),
      SmartPlaylist(
        kind: SmartPlaylistKind.liked,
        title: 'Только лайки',
        tracks: lib.liked,
      ),
    ].where((s) => q.isEmpty || s.title.toLowerCase().contains(q)).toList();

/// Строки вида «Артист — Трек» из буфера: режем по переводу строки, срезаем
/// края, пустые выбрасываем (пользователь часто оставляет пустые строки).
List<String> parseTrackLines(String text) => text
    .split('\n')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// Плейлист Яндекс Музыки в том виде, в каком его отдаёт источник.
class YandexPlaylist {
  const YandexPlaylist({
    required this.kind,
    required this.title,
    required this.count,
  });

  final int kind;
  final String title;
  final int count;
}

/// Куда сложить лайки YouTube Music.
enum YoutubeLikesTarget { playlist, liked }

/// Найденные треки и размер входа — нужно, чтобы сказать
/// «Импортировано: 7 из 12», не теряя честный масштаб потерь.
class MatchedTracks {
  const MatchedTracks(this.tracks, this.total);

  final List<Track> tracks;
  final int total;
}

/// Исход шага импорта. Импорт — обычный пользовательский сценарий, а не
/// аварийная ситуация, поэтому ошибки возвращаются значением, а не
/// исключением: вызывающий экран всегда покажет снекбар и не уронит поток.
class ImportResult<T> {
  const ImportResult.success(this.value) : message = null;
  const ImportResult.failure(this.message) : value = null;
  /// Пользователь закрыл диалог/отменил выбор — сообщать нечего.
  const ImportResult.cancelled() : value = null, message = null;

  final T? value;
  final String? message;
}

/// Сколько запросов в агрегатор летит одновременно при импорте Spotify.
/// Пул ограничен намеренно: плейлист на 500 треков иначе устроит 500
/// параллельных поисков, которые источники не выдержат.
const int spotifyMatchWorkers = 5;

/// Действия экрана библиотеки: импорт, экспорт, дедупликация.
///
/// Виджеты не должны знать, откуда берутся данные — они только спрашивают
/// ввод у пользователя и показывают то, что вернул контроллер (снекбар,
/// следующий шаг). Всё «сетевое» и «файловое» живёт здесь, чтобы при смене
/// оформления правилась только вёрстка.
class LibraryActions {
  LibraryActions(this._ref);

  final WidgetRef _ref;

  // ---------------------------------------------------------------- Spotify

  /// Импорт плейлиста/альбома по ссылке Spotify. Возвращает текст для
  /// снекбара; null — показать нечего.
  Future<String?> importFromSpotify(String url) async {
    final ({String name, List<String> queries}) data;
    try {
      data = await _ref.read(spotifyImportProvider).fetch(url.trim());
    } catch (e) {
      return '$e';
    }
    // Матчим каждый трек в нашем агрегаторе (пулом, с сохранением порядка).
    final matched = List<Track?>.filled(data.queries.length, null);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= data.queries.length) break;
        try {
          final r = await _ref.read(aggregatorProvider).search(data.queries[i]);
          if (r.isNotEmpty) matched[i] = r.first;
        } catch (_) {} // один мёртвый запрос не должен ронять весь импорт
      }
    }

    await Future.wait([for (var i = 0; i < spotifyMatchWorkers; i++) worker()]);
    final tracks = matched.whereType<Track>().toList();
    if (tracks.isEmpty) {
      return 'Ничего не удалось найти по этому плейлисту';
    }
    await _ref.read(libraryProvider).importPlaylist(data.name, tracks);
    return 'Импортировано: ${tracks.length} из ${data.queries.length}';
  }

  // ---------------------------------------------------------------- YouTube

  /// Импорт по ссылке на плейлист YouTube.
  Future<String?> importFromYoutube(String url) async {
    try {
      final res = await _ref.read(youtubeSourceProvider).importPlaylist(url);
      await _ref.read(libraryProvider).importPlaylist(res.title, res.tracks);
      return 'Импортировано: ${res.title} (${res.tracks.length} треков)';
    } catch (e) {
      return 'Ошибка импорта: $e';
    }
  }

  /// Лайки YouTube Music. Шаг 1 — забрать треки (нужен отдельный вход Google),
  /// шаг 2 — спросить у пользователя, куда их положить.
  Future<ImportResult<List<Track>>> fetchYoutubeLikes() async {
    try {
      final tracks = await _ref.read(googleYtImportProvider).importLikedVideos();
      if (tracks.isEmpty) {
        return const ImportResult.failure('Лайкнутых треков не найдено');
      }
      return ImportResult.success(tracks);
    } catch (e) {
      return ImportResult.failure('Ошибка входа/импорта: $e');
    }
  }

  /// Шаг 2 импорта лайков: сохранить их плейлистом или в «Избранное».
  Future<String?> saveYoutubeLikes(
      List<Track> tracks, YoutubeLikesTarget target) async {
    if (target == YoutubeLikesTarget.playlist) {
      await _ref
          .read(libraryProvider)
          .importPlaylist('YouTube — Мне понравилось', tracks);
      return 'Импортировано плейлистом: ${tracks.length}';
    }
    await _ref.read(libraryProvider).addManyToLiked(tracks);
    return 'Добавлено в Избранное: ${tracks.length}';
  }

  // ----------------------------------------------------------------- Яндекс

  /// Плейлисты пользователя в Яндекс Музыке. Без токена источника смысла нет —
  /// [missingYandexToken] объясняет это раньше, чем экран включит «загрузку».
  Future<ImportResult<List<YandexPlaylist>>> fetchYandexPlaylists() async {
    final missing = missingYandexToken;
    if (missing != null) return ImportResult.failure(missing);
    try {
      final pls = await _ref.read(yandexSourceProvider).userPlaylists();
      return ImportResult.success([
        for (final p in pls)
          YandexPlaylist(kind: p.kind, title: p.title, count: p.count),
      ]);
    } catch (e) {
      return ImportResult.failure('Ошибка: $e');
    }
  }

  /// Сообщение о недостающем токене Яндекса либо null, если импортировать можно.
  /// Отдельный геттер, чтобы экран мог спросить ДО «крутилки»: мигать индикатором
  /// ради заведомо пустого результата незачем.
  String? get missingYandexToken => _ref.read(settingsProvider).hasYandexToken
      ? null
      : 'Сначала добавьте токен Яндекса в Настройках';

  /// Треки выбранного плейлиста Яндекса — сохраняем в нашу библиотеку.
  Future<String?> importYandexPlaylist(YandexPlaylist picked) async {
    try {
      final tracks =
          await _ref.read(yandexSourceProvider).playlistTracks(picked.kind);
      await _ref.read(libraryProvider).importPlaylist(picked.title, tracks);
      return 'Импортировано: ${picked.title} (${tracks.length} треков)';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  // -------------------------------------------------------------- Список/файл

  /// Шаг 1 импорта по списку: ищем каждую строку в агрегаторе. Имя плейлиста
  /// спрашивает экран — только когда уже ясно, что что-то нашлось.
  Future<ImportResult<MatchedTracks>> matchTextList(String text) async {
    final lines = parseTrackLines(text);
    // Пустой ввод — это не ошибка, а «пользователь ничего не вставил».
    if (lines.isEmpty) return const ImportResult.cancelled();
    final tracks = <Track>[];
    for (final line in lines) {
      try {
        final r = await _ref.read(aggregatorProvider).search(line);
        if (r.isNotEmpty) tracks.add(r.first);
      } catch (_) {} // строка не нашлась — идём к следующей
    }
    if (tracks.isEmpty) {
      return const ImportResult.failure('Ничего не найдено по списку');
    }
    return ImportResult.success(MatchedTracks(tracks, lines.length));
  }

  /// Шаг 2 импорта по списку: сохранить найденное под именем.
  Future<String?> saveTextList(MatchedTracks found, String name) async {
    await _ref.read(libraryProvider).importPlaylist(name, found.tracks);
    return 'Импортировано: ${found.tracks.length} из ${found.total}';
  }

  /// Импорт плейлиста из JSON-файла. Сам выбор файла делает экран (это
  /// системный диалог), сюда приходит уже прочитанный текст.
  Future<String?> importPlaylistJson(String content) async {
    try {
      final data = jsonDecode(content);
      final map = (data as Map).cast<String, dynamic>();
      final name = (map['name'] as String?) ?? 'Импортированный плейлист';
      final tracks = ((map['tracks'] as List?) ?? [])
          .map((e) => Track.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (tracks.isEmpty) {
        return 'Файл пуст или неверного формата';
      }
      await _ref.read(libraryProvider).importPlaylist(name, tracks);
      return 'Импортировано: $name (${tracks.length} треков)';
    } catch (e) {
      return 'Ошибка импорта файла: $e';
    }
  }

  // ---------------------------------------------- локальные плейлисты/очередь

  /// Экспорт одного плейлиста в JSON и «Поделиться». Ошибка шаринга не
  /// критична (пользователь мог закрыть системный диалог) — молча выходим.
  Future<void> exportPlaylist(PlaylistX pl) async {
    try {
      final data = {
        'roundds_playlist': 1,
        'name': pl.name,
        'tracks': pl.tracks.map((t) => t.toJson()).toList(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final safe = pl.name.replaceAll(RegExp(r'[^\wА-Яа-яЁё -]'), '_');
      await shareTextFile(json,
          filename: '$safe.json',
          mime: 'application/json',
          text: 'vvavve — плейлист «${pl.name}»');
    } catch (_) {/* отмена/ошибка шаринга не критична */}
  }

  /// Чистка плейлиста от дублей. Возвращает текст для снекбара.
  Future<String> removeDuplicates(String playlistId) async {
    final n = await _ref.read(libraryProvider).removeDuplicates(playlistId);
    return n == 0 ? 'Дубликатов не найдено' : 'Удалено дубликатов: $n';
  }

  /// Скачать все лайки одним плейлистом. null — кнопка не нажата по делу
  /// (нечего качать или уже качается другой плейлист).
  Future<String?> downloadLiked() async {
    final liked = _ref.read(libraryProvider).liked;
    if (liked.isEmpty || _ref.read(downloadsProvider).playlistBusy) return null;
    _ref.read(downloadsProvider).downloadPlaylist('Избранное', liked);
    return 'Скачивание «Избранное»…';
  }

  /// Сохранить показанную очередь плейлистом. Очередь передаётся из экрана:
  /// он её уже показывает, а перечитывать из плеера во время диалога — значит
  /// рисковать посчитать не то, что сохранили.
  Future<String?> saveQueueAsPlaylist(String name, List<Track> queue) async {
    await _ref.read(libraryProvider).importPlaylist(name, queue);
    return 'Сохранено: $name (${queue.length} треков)';
  }
}
