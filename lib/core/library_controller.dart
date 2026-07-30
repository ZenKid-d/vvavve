import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/album_result.dart';
import '../domain/models/playlist.dart';
import '../domain/models/track.dart';
import '../sync/artist_flags.dart';
import '../sync/device_id.dart';
import '../sync/sync_clock.dart';
import '../sync/synced_set.dart';
import '../sync/track_stat.dart';
import 'diagnostics.dart';

/// Локальная медиатека: история прослушивания, лайки и пользовательские
/// плейлисты. Хранится в SharedPreferences как JSON (без codegen).
///
/// Формат хранения — v2: не голый список значений, а записи с меткой времени и
/// признаком удаления (см. [SyncedSet]). Это нужно для синхронизации между
/// устройствами: в v1 снятый лайк был неотличим от лайка, которого никогда не
/// было, поэтому любое слияние воскрешало бы удалённое. Ключи prefs те же —
/// меняется только форма значения, старый формат распознаётся и переносится.
class LibraryController extends ChangeNotifier {
  LibraryController(this._prefs) {
    _deviceId = DeviceId.ensure(_prefs);
    _load();
  }

  final SharedPreferences _prefs;

  /// Идентификатор установки: им подписаны правки (для разрешения ничьих) и
  /// по нему ведётся собственный счётчик прослушиваний.
  late final String _deviceId;

  /// Сколько последних треков держим в истории прослушивания. Старые
  /// вытесняются (FIFO) — история нужна для «недавнее», а не как архив.
  static const int maxHistory = 50;

  /// Надгробия старше этого срока подчищаются: своё дело они сделали, а место
  /// занимают. Срок заведомо больше разумного офлайна — иначе удаление
  /// «забудется» и запись воскреснет с другого устройства.
  static const Duration tombstoneTtl = Duration(days: 90);

  final List<Track> _history = [];

  late final SyncedSet<Track> _liked = SyncedSet<Track>(
    encode: (t) => t.toJson(),
    decode: Track.fromJson,
    deviceId: _deviceId,
  );
  late final SyncedSet<AlbumResult> _likedAlbums = _albumSet();
  late final SyncedSet<AlbumResult> _dislikedAlbums = _albumSet();
  late final SyncedSet<PlaylistX> _playlists = SyncedSet<PlaylistX>(
    encode: (p) => p.toJson(),
    decode: PlaylistX.fromJson,
    deviceId: _deviceId,
  );
  late final SyncedSet<ArtistFlags> _artists = SyncedSet<ArtistFlags>(
    encode: (a) => a.toJson(),
    decode: ArtistFlags.fromJson,
    deviceId: _deviceId,
  );
  late final SyncedSet<TrackStat> _stats = SyncedSet<TrackStat>(
    encode: (s) => s.toJson(),
    decode: TrackStat.fromJson,
    deviceId: _deviceId,
  );

  SyncedSet<AlbumResult> _albumSet() => SyncedSet<AlbumResult>(
        encode: (a) => a.toJson(),
        decode: AlbumResult.fromJson,
        deviceId: _deviceId,
      );

  /// Время прослушивания — тоже по устройствам: суммировать одно общее число
  /// при синхронизации нельзя, оно бы росло с каждым обменом.
  final Map<String, int> _listenedByDevice = {};

  // Кэш отсортированных топов — пересортировка по всем прослушанным трекам
  // дорогая, а статы меняются редко (на проигрывание). Сбрасываем при мутации.
  List<MapEntry<Track, int>>? _topTracksCache;
  List<MapEntry<String, int>>? _topArtistsCache;
  void _invalidateStatCaches() {
    _topTracksCache = null;
    _topArtistsCache = null;
  }

  /// Вызывается при добавлении лайка (для авто-скачивания). Ставится в провайдере.
  void Function(Track track)? onTrackLiked;

  List<Track> get history => List.unmodifiable(_history);
  List<PlaylistX> get playlists => List.unmodifiable(_playlists.values);
  List<Track> get liked => List.unmodifiable(_liked.values);
  List<AlbumResult> get likedAlbums => List.unmodifiable(_likedAlbums.values);
  List<AlbumResult> get dislikedAlbums =>
      List.unmodifiable(_dislikedAlbums.values);

  // --- Подписки на артистов ---

  List<String> get followedArtists =>
      [for (final a in _artists.values.where((a) => a.followed)) a.name];

  bool isFollowing(String artist) =>
      _artists[ArtistFlags.keyOf(artist)]?.followed ?? false;

  Future<void> toggleFollow(String artist) async {
    final a = artist.trim();
    if (a.isEmpty) return;
    await _updateArtist(a, followed: !isFollowing(a));
  }

  // --- Чёрный список артистов ---

  List<String> get blacklistedArtists =>
      [for (final a in _artists.values.where((a) => a.blacklisted)) a.key]
        ..sort();

  bool isArtistBlacklisted(String artist) =>
      _artists[ArtistFlags.keyOf(artist)]?.blacklisted ?? false;

  Future<void> blacklistArtist(String artist) async {
    if (artist.trim().isEmpty) return;
    await _updateArtist(artist.trim(), blacklisted: true);
  }

  Future<void> unblacklistArtist(String artist) async {
    if (artist.trim().isEmpty) return;
    await _updateArtist(artist.trim(), blacklisted: false);
  }

  /// Меняет флаги артиста одной записью. Когда не осталось ни подписки, ни
  /// чёрного списка, запись удаляется — с надгробием, чтобы удаление доехало
  /// до других устройств.
  Future<void> _updateArtist(String name,
      {bool? followed, bool? blacklisted}) async {
    final key = ArtistFlags.keyOf(name);
    final current = _artists[key] ?? ArtistFlags(name: name);
    final next = current.copyWith(
      name: name,
      followed: followed,
      blacklisted: blacklisted,
    );
    if (next.isEmpty) {
      _artists.remove(key);
    } else {
      _artists.upsert(key, next);
    }
    await _persist('artists', _artists);
    notifyListeners();
  }

  /// Безопасный поиск плейлиста по id. Возвращает null, если плейлиста нет —
  /// например, когда его успели удалить между открытием меню и тапом по
  /// действию (гонка UI). Все мутации плейлиста идут через этот метод и
  /// молча no-op, чтобы не бросать StateError в рантайме.
  PlaylistX? _findById(String id) => _playlists[id];

  /// Убирает дубликаты треков в плейлисте (по uid и по «артист — название»).
  /// Возвращает число удалённых дубликатов (0, если плейлист уже удалён).
  Future<int> removeDuplicates(String playlistId) async {
    final pl = _findById(playlistId);
    if (pl == null) return 0;
    final seenUid = <String>{};
    final seenName = <String>{};
    final before = pl.tracks.length;
    pl.tracks.retainWhere((t) {
      final nameKey = '${t.artist.toLowerCase()}—${t.title.toLowerCase()}';
      final dupUid = !seenUid.add(t.uid);
      final dupName = !seenName.add(nameKey);
      return !(dupUid || dupName);
    });
    await _touchPlaylist(pl);
    return before - pl.tracks.length;
  }

  void _load() {
    _loadHistory();
    _loadSet('liked', _liked, (t) => t.uid, Track.fromJson);
    _loadSet('playlists', _playlists, (p) => p.id, PlaylistX.fromJson);
    _loadSet('liked_albums', _likedAlbums, (a) => a.uid, AlbumResult.fromJson);
    _loadSet(
        'disliked_albums', _dislikedAlbums, (a) => a.uid, AlbumResult.fromJson);
    _loadArtists();
    _loadStats();
    _loadListened();
    _gcTombstones();
    notifyListeners();
  }

  void _loadHistory() {
    // История остаётся простым списком: она обрезана до 50 записей и живёт как
    // «недавнее», а не как состояние, которое надо сливать по записям.
    final h = _prefs.getString('history');
    if (h == null) return;
    try {
      _history
        ..clear()
        ..addAll((jsonDecode(h) as List)
            .map((e) => Track.fromJson((e as Map).cast<String, dynamic>())));
    } catch (e) {
      Diagnostics.instance.warn('library', 'История не прочитана: $e');
    }
  }

  /// Читает множество: сначала как v2, иначе переносит старый формат.
  void _loadSet<T>(
    String key,
    SyncedSet<T> set,
    String Function(T value) keyOf,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      if (set.decodeV2(raw)) return;
      final items = (jsonDecode(raw) as List)
          .map((e) => fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      set.decodeV1(items, keyOf, stampedAt: SyncClock.now());
      _migrated(key, raw, items.length);
    } catch (e) {
      Diagnostics.instance.warn('library', 'Ключ $key не прочитан: $e');
      _restoreBackup(key, set, keyOf, fromJson);
    }
  }

  /// Артисты: в v1 это были два разных ключа — подписки (с регистром) и
  /// чёрный список (в нижнем регистре). Сводим их в одну запись на артиста.
  void _loadArtists() {
    final raw = _prefs.getString('artists');
    if (raw != null && raw.isNotEmpty) {
      try {
        if (_artists.decodeV2(raw)) return;
      } catch (e) {
        Diagnostics.instance.warn('library', 'Артисты не прочитаны: $e');
      }
    }
    final followed = _prefs.getStringList('followed_artists') ?? const [];
    final blacklist = _prefs.getStringList('blacklist_artists') ?? const [];
    if (followed.isEmpty && blacklist.isEmpty) return;

    final merged = <String, ArtistFlags>{};
    for (final name in followed) {
      merged[ArtistFlags.keyOf(name)] =
          ArtistFlags(name: name, followed: true);
    }
    for (final name in blacklist) {
      final key = ArtistFlags.keyOf(name);
      merged[key] = (merged[key] ?? ArtistFlags(name: name))
          .copyWith(blacklisted: true);
    }
    _artists.decodeV1(merged.values, (a) => a.key, stampedAt: SyncClock.now());
    unawaited(_persist('artists', _artists));
    Diagnostics.instance.info('library',
        'Артисты перенесены в новый формат: ${merged.length} записей');
  }

  void _loadStats() {
    final raw = _prefs.getString('stats');
    if (raw == null || raw.isEmpty) return;
    try {
      if (_stats.decodeV2(raw)) {
        _invalidateStatCaches();
        return;
      }
      // v1: {track, count} одним числом — записываем его как вклад этого
      // устройства, иначе при первой же синхронизации счётчики задвоятся.
      final items = <TrackStat>[];
      for (final e in (jsonDecode(raw) as List)) {
        final m = (e as Map).cast<String, dynamic>();
        final t = Track.fromJson((m['track'] as Map).cast<String, dynamic>());
        final c = (m['count'] as num?)?.toInt() ?? 0;
        items.add(TrackStat(track: t, counts: {_deviceId: c}));
      }
      _stats.decodeV1(items, (s) => s.track.uid, stampedAt: SyncClock.now());
      _migrated('stats', raw, items.length);
      _invalidateStatCaches();
    } catch (e) {
      Diagnostics.instance.warn('library', 'Статистика не прочитана: $e');
    }
  }

  void _loadListened() {
    final raw = _prefs.getString('listened_ms_v2');
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _listenedByDevice
          ..clear()
          ..addAll({
            for (final e in m.entries) e.key: (e.value as num).toInt(),
          });
        return;
      } catch (e) {
        Diagnostics.instance.warn('library', 'Время прослушивания не прочитано: $e');
      }
    }
    // Суммарное время прослушивания. Если ещё не считалось — разовая оценка
    // из статистики (кол-во прослушиваний × длительность трека).
    var legacy = _prefs.getInt('listened_ms') ?? -1;
    if (legacy < 0) {
      var est = 0;
      for (final s in _stats.values) {
        final d = s.track.duration;
        if (d != null) est += d.inMilliseconds * s.total;
      }
      legacy = est;
    }
    _listenedByDevice[_deviceId] = legacy;
    unawaited(_persistListened());
  }

  /// Сохраняем копию старого значения перед первой записью в новом формате:
  /// если что-то пойдёт не так, откатываемся к ней, а не к пустой библиотеке.
  void _migrated(String key, String rawV1, int count) {
    final backupKey = '${key}__v1_backup';
    if (!_prefs.containsKey(backupKey)) _prefs.setString(backupKey, rawV1);
    Diagnostics.instance
        .info('library', 'Ключ $key перенесён в новый формат: $count записей');
  }

  void _restoreBackup<T>(
    String key,
    SyncedSet<T> set,
    String Function(T value) keyOf,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final backup = _prefs.getString('${key}__v1_backup');
    if (backup == null) return;
    try {
      final items = (jsonDecode(backup) as List)
          .map((e) => fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      set.decodeV1(items, keyOf, stampedAt: SyncClock.now());
      Diagnostics.instance
          .warn('library', 'Ключ $key восстановлен из резервной копии');
    } catch (e) {
      Diagnostics.instance.warn('library', 'Резервная копия $key тоже битая: $e');
    }
  }

  void _gcTombstones() {
    final before = DateTime.now().subtract(tombstoneTtl).millisecondsSinceEpoch;
    for (final set in [_liked, _likedAlbums, _dislikedAlbums, _artists]) {
      set.gcTombstones(before: before);
    }
    _playlists.gcTombstones(before: before);
  }

  Future<void> _persist<T>(String key, SyncedSet<T> set) =>
      _prefs.setString(key, set.encode());

  Future<void> _persistListened() =>
      _prefs.setString('listened_ms_v2', jsonEncode(_listenedByDevice));

  Duration get totalListened => Duration(
      milliseconds: _listenedByDevice.values.fold(0, (sum, ms) => sum + ms));

  int get uniqueTracks => _stats.length;

  int get uniqueArtists =>
      _stats.values.map((s) => s.track.artist).toSet().length;

  Future<void> addListened(int ms) async {
    if (ms <= 0) return;
    _listenedByDevice[_deviceId] = (_listenedByDevice[_deviceId] ?? 0) + ms;
    await _persistListened();
    notifyListeners();
  }

  /// Топ треков по числу прослушиваний.
  List<MapEntry<Track, int>> topTracks({int limit = 50}) {
    final all = _topTracksCache ??= (_stats.values
        .map((s) => MapEntry(s.track, s.total))
        .toList()
      ..sort((a, b) => b.value - a.value));
    return all.take(limit).toList();
  }

  /// Топ артистов по суммарному числу прослушиваний.
  List<MapEntry<String, int>> topArtists({int limit = 20}) {
    final all = _topArtistsCache ??= (() {
      final byArtist = <String, int>{};
      for (final s in _stats.values) {
        byArtist[s.track.artist] = (byArtist[s.track.artist] ?? 0) + s.total;
      }
      return byArtist.entries.toList()..sort((a, b) => b.value - a.value);
    })();
    return all.take(limit).toList();
  }

  int get totalPlays => _stats.values.fold(0, (sum, s) => sum + s.total);

  bool isLiked(Track t) => _liked.contains(t.uid);

  Future<void> addManyToLiked(List<Track> tracks) async {
    for (final t in tracks) {
      if (!_liked.contains(t.uid)) _liked.upsert(t.uid, t);
    }
    await _persist('liked', _liked);
    notifyListeners();
  }

  Future<void> toggleLike(Track t) async {
    if (isLiked(t)) {
      _liked.remove(t.uid);
    } else {
      _liked.upsert(t.uid, t);
      onTrackLiked?.call(t); // авто-скачивание, если включено
    }
    await _persist('liked', _liked);
    notifyListeners();
  }

  // --- Лайки/дизлайки альбомов ---

  bool isAlbumLiked(AlbumResult a) => _likedAlbums.contains(a.uid);
  bool isAlbumDisliked(AlbumResult a) => _dislikedAlbums.contains(a.uid);

  /// Лайк отменяет дизлайк того же альбома — противоречивое состояние
  /// (лайкнут и дизлайкнут одновременно) не нужно.
  Future<void> toggleLikeAlbum(AlbumResult a) async {
    if (isAlbumLiked(a)) {
      _likedAlbums.remove(a.uid);
    } else {
      _likedAlbums.upsert(a.uid, a);
      if (isAlbumDisliked(a)) {
        _dislikedAlbums.remove(a.uid);
        await _persist('disliked_albums', _dislikedAlbums);
      }
    }
    await _persist('liked_albums', _likedAlbums);
    notifyListeners();
  }

  Future<void> toggleDislikeAlbum(AlbumResult a) async {
    if (isAlbumDisliked(a)) {
      _dislikedAlbums.remove(a.uid);
    } else {
      _dislikedAlbums.upsert(a.uid, a);
      if (isAlbumLiked(a)) {
        _likedAlbums.remove(a.uid);
        await _persist('liked_albums', _likedAlbums);
      }
    }
    await _persist('disliked_albums', _dislikedAlbums);
    notifyListeners();
  }

  Future<void> pushHistory(Track t) async {
    _history.removeWhere((e) => e.uid == t.uid);
    _history.insert(0, t);
    if (_history.length > maxHistory) {
      _history.removeRange(maxHistory, _history.length);
    }
    final current = _stats[t.uid] ?? TrackStat(track: t, counts: const {});
    _stats.upsert(t.uid, current.increment(_deviceId));
    _invalidateStatCaches();
    await _persistHistory();
    await _persist('stats', _stats);
    notifyListeners();
  }

  Future<PlaylistX> createPlaylist(String name) async {
    final pl = PlaylistX(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _playlists.upsert(pl.id, pl);
    await _persist('playlists', _playlists);
    notifyListeners();
    return pl;
  }

  Future<PlaylistX> importPlaylist(String name, List<Track> tracks) async {
    final pl = PlaylistX(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      tracks: List.of(tracks),
    );
    _playlists.upsert(pl.id, pl);
    await _persist('playlists', _playlists);
    notifyListeners();
    return pl;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final pl = _findById(id);
    if (pl == null) return;
    pl.name = name;
    await _touchPlaylist(pl);
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.remove(id);
    await _persist('playlists', _playlists);
    notifyListeners();
  }

  Future<void> addToPlaylist(String id, Track t) async {
    final pl = _findById(id);
    if (pl == null) return;
    if (!pl.tracks.any((e) => e.uid == t.uid)) {
      pl.tracks.add(t);
      await _touchPlaylist(pl);
    }
  }

  Future<void> removeFromPlaylist(String id, Track t) async {
    final pl = _findById(id);
    if (pl == null) return;
    pl.tracks.removeWhere((e) => e.uid == t.uid);
    await _touchPlaylist(pl);
  }

  /// Плейлист меняется на месте (список треков мутабельный), поэтому запись
  /// нужно переложить заново — иначе метка времени останется старой и правка
  /// не уедет на другие устройства.
  Future<void> _touchPlaylist(PlaylistX pl) async {
    _playlists.upsert(pl.id, pl);
    await _persist('playlists', _playlists);
    notifyListeners();
  }

  /// Полный экспорт библиотеки (плейлисты, лайки, история, статистика).
  ///
  /// Формат остаётся первой версии: файлы бэкапов должны читаться и старыми
  /// сборками, и наоборот.
  Map<String, dynamic> exportData() => {
        'version': 1,
        'playlists': _playlists.values.map((e) => e.toJson()).toList(),
        'liked': _liked.values.map((e) => e.toJson()).toList(),
        'history': _history.map((e) => e.toJson()).toList(),
        'stats': _stats.values
            .map((s) => {'track': s.track.toJson(), 'count': s.total})
            .toList(),
      };

  /// Импорт (слияние) библиотеки из бэкапа.
  ///
  /// Семантика намеренно отличается от синхронизации: здесь объединение и
  /// суммирование счётчиков — так ведёт себя восстановление из файла, которое
  /// делают руками и один раз. Синхронизация, наоборот, сливает по меткам
  /// времени и счётчики не складывает (иначе они росли бы с каждым обменом).
  ///
  /// Битые записи (отсутствует id, не тот тип) пропускаем, а не роняем весь
  /// импорт — так частично повреждённый бэкап восстановит что сможет. Причина
  /// каждого пропуска пишется в диагностику.
  Future<void> importData(Map<String, dynamic> data) async {
    var skipped = 0;
    for (final e in (data['playlists'] as List? ?? [])) {
      try {
        final pl = PlaylistX.fromJson((e as Map).cast<String, dynamic>());
        if (!_playlists.contains(pl.id)) _playlists.upsert(pl.id, pl);
      } catch (err) {
        skipped++;
        Diagnostics.instance.warn('library', 'Импорт: битый плейлист пропущен: $err');
      }
    }
    for (final e in (data['liked'] as List? ?? [])) {
      try {
        final t = Track.fromJson((e as Map).cast<String, dynamic>());
        if (!_liked.contains(t.uid)) _liked.upsert(t.uid, t);
      } catch (err) {
        skipped++;
        Diagnostics.instance.warn('library', 'Импорт: битый лайк пропущен: $err');
      }
    }
    for (final e in (data['stats'] as List? ?? [])) {
      try {
        final m = (e as Map).cast<String, dynamic>();
        final t = Track.fromJson((m['track'] as Map).cast<String, dynamic>());
        final c = (m['count'] as num?)?.toInt() ?? 0;
        final current = _stats[t.uid] ?? TrackStat(track: t, counts: const {});
        _stats.upsert(t.uid, current.increment(_deviceId, c));
      } catch (err) {
        skipped++;
        Diagnostics.instance.warn('library', 'Импорт: битая запись stats пропущена: $err');
      }
    }
    if (skipped > 0) {
      Diagnostics.instance
          .warn('library', 'Импорт завершён, пропущено битых записей: $skipped');
    }
    _invalidateStatCaches();
    await _persist('playlists', _playlists);
    await _persist('liked', _liked);
    await _persist('stats', _stats);
    notifyListeners();
  }

  Future<void> _persistHistory() => _prefs.setString(
      'history', jsonEncode(_history.map((e) => e.toJson()).toList()));
}
