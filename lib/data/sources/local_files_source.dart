import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../domain/music_source.dart';
import '../../domain/models/playable_stream.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';

/// Аудио-файлы на устройстве: скан Music/Download/DCIM через dart:io
/// (MediaStore-канал — отдельная работа, см. ROADMAP), воспроизведение
/// напрямую из файла, без сети.
///
/// Метадата читается из ИМЕНИ файла («Артист — Название.mp3»); ID3-теги
/// читаются только плеером ОС при воспроизведении. Секунд нет — длительность
/// узнает сам just_audio. Не путать со скачанным кэшем (downloads): те лечат
/// uid сетевого трека, эти filesystem самостоятельны.
class LocalFilesSource implements MusicSource {
  LocalFilesSource();

  /// Расширения, которые считаем аудио. flac/m4a/wav явно перечислены:
  /// по-extension фильтр самый дешёвый и предсказуемый (MediaStore нельзя
  /// без нативного канала).
  static const _audioExt = {
    '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.flac', '.wav', '.wma',
  };

  /// Каталоги для скана: публичная музыка, загрузки, DCIM. Добавление новых
  /// — вопрос ещё одного пути в списке, не логики.
  static const _dirs = <String>[
    'Music',
    'Download',
    'DCIM',
  ];

  /// Кэш последнего скана. Повторное открытие вкладки не переходит по
  /// файловой системе заново: invalidate() сбрасывает руками (pull-to-refresh).
  List<Track>? _cache;

  /// uid и есть абсолютный путь (без понижения регистра: файловая система
  /// Android case-sensitive). Файл переименован/переехал — это другой трек,
  /// и это честно: Track.uid = 'local:$id' собирает префикс сам.

  /// сброс кеша. Вызывается pull-to-refresh и включением источника.
  void invalidate() => _cache = null;

  /// Разбирает «Артист — Название [видео] .mp3» в трек. Замена — на среднего
  /// разделителя, потому что « — » внутри артиста встречается реже, чем в
  /// названиях (e.g. AC/DC — Back In Black).
  static Track trackFromFile(String path, {DateTime? modified}) {
    final name = _baseName(path);
    final dot = name.lastIndexOf('.');
    final base =
        dot > 0 ? name.substring(0, dot) : name; // .mp3 → «Артист — Название»
    final artistTitle = _splitBase(base);
    // id — без префикса источника: Track.uid = '$source:$id' собирает его сам.
    return Track(
      id: path,
      title: artistTitle.title,
      artist: artistTitle.artist,
      album: null,
      artworkUrl: null,
      source: SourceType.local,
      duration: null,
      extra: {
        'localPath': path,
        if (modified != null) 'modifiedTs': modified.millisecondsSinceEpoch,
      },
    );
  }

  /// Имя файла/каталога без пути: Android даёт «/», Windows — «\».
  /// Берём последний из обоих, чтобы тесты гоняли unix-пути на Windows.
  static String _baseName(String path) =>
      path.substring(path.lastIndexOf(RegExp(r'[/\\]')) + 1);

  /// «AC/DC — Hells Bells» → (AC/DC, Hells Bells); без разделителя →
  /// (Артист неизвестен, всё в название).
  static ({String artist, String title}) _splitBase(String base) {
    for (final sep in const [' — ', ' - ', ' – ', '_-_', ' —']) {
      final i = base.indexOf(sep);
      if (i > 0 && i < base.length - sep.length) {
        return (
          artist: base.substring(0, i).trim(),
          title: base.substring(i + sep.length).trim(),
        );
      }
    }
    return (artist: 'На устройстве', title: base.trim());
  }

  /// Основа скана: каталоги /storage/emulated/0/{[dir]}. Слушаем также
  /// primary external storage, если он другой (режкие кастомы).
  /// Поле, а не только static: тесты подменяют на временный каталог
  /// (на Windows-хосте Android-корней нет).
  List<Directory> Function() scanTargets = _scanDirs;

  static List<Directory> _scanDirs() {
    final out = <Directory>[];
    for (final root in const [
      '/storage/emulated/0',
      '/sdcard',
    ]) {
      for (final d in _dirs) {
        final dir = Directory('$root/$d');
        if (dir.existsSync()) out.add(dir);
      }
    }
    return out;
  }

  /// Рекурсивный обход каталога в глубину с ограничением по глубине и по
  /// числу файлов: песён в 10k+ не ожидаем, но du-обход без ограничений
  /// подвесит сканер на SD с картинками. 6 уровней хватит для человеческих
  /// человеческих структур (Music/Артист/Альбом/[диск]/…).
  static const _maxDepth = 6;
  static const _maxFiles = 5000;

  @override
  SourceType get type => SourceType.local;

  @override
  Future<bool> get isReady async {
    if (_cache != null && _cache!.isNotEmpty) return true;
    final tracks = await search('', limit: 1);
    return tracks.isNotEmpty;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20, int page = 0}) async {
    // Скан — тяжёлый синхронный обход FS, его нельзя делать на каждый
    // запрос. Пока кэша нет — запускаем в фоне и отдаём пусто: UI не
    // фризится, следующий запрос (или открытие вкладки «На устройстве»)
    // уже увидит результат.
    if (_cache == null) {
      unawaited(scan());
      return const [];
    }
    // Поиск = фильтр уже отсканированного: файлы не в сети, ждать каждый
    // запрос по-новому незачем. page игнорируем — выдача одноразовая.
    final tracks = _cache!;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.of(tracks);
    return [
      for (final t in tracks)
        if (t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q))
          t,
    ];
  }

  @override
  bool get supportsPaging => false;

  /// Сканирует медиа-каталоги в список треков. Перед сканом запрашивает
  /// гранулярное аудио-разрешение (READ_MEDIA_AUDIO на Android 13+) —
  /// без него listSync вернёт пусто или упадёт, а пользователь ничего
  /// не поймёт. Отказ — честный пустой результат (см. Принцип II).
  Future<List<Track>> scan() async {
    // Шов для тестов: permission_handler в тестовом окружении без платформы
    // роняет MethodChannel. Реальный гейт грузится Android-девайсом.
    final granted = await permissionGate();
    if (!granted) return const [];
    final all = <Track>[];
    scanAsync:
    for (final dir in scanTargets()) {
      final stack = <(Directory, int)>[(dir, 0)];
      while (stack.isNotEmpty) {
        final (d, depth) = stack.removeLast();
        if (depth > _maxDepth) continue;
        List<FileSystemEntity> entries;
        try {
          entries = d.listSync(followLinks: false);
        } catch (_) {
          continue; // нет прав/каталог исчез — пропускаем ветку
        }
        for (final e in entries) {
          if (all.length >= _maxFiles) break scanAsync;
          if (e is Directory) {
            // Скрытые и системные не трогаем. Базовое имя — по обоим
            // разделителям: Windows-хост даёт «\».
            final n = _baseName(e.path);
            if (n.startsWith('.') || n == 'Android' || n == 'nomedia') {
              continue;
            }
            stack.add((e, depth + 1));
          } else if (e is File) {
            final t = _trackIfAudio(e);
            if (t != null) all.add(t);
          }
        }
      }
    }
    all.sort((a, b) => a.artist.compareTo(b.artist) != 0
        ? a.artist.compareTo(b.artist)
        : a.title.compareTo(b.title));
    _cache = all;
    return all;
  }

  /// Отбирает файл по аудио-расширению. Возраст не фильтруем: пользователь
  /// может закинуть в Download что угодно — если расширение аудио, значит
  /// сам так решил.
  Track? _trackIfAudio(File f) {
    final dot = f.path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = f.path.substring(dot).toLowerCase();
    if (!_audioExt.contains(ext)) return null;
    DateTime? modified;
    try {
      modified = f.statSync().modified;
    } catch (_) {}
    return trackFromFile(f.path, modified: modified);
  }

  @override
  Future<List<Track>> feed({int limit = 20}) async {
    // «Файлы» не участвуют в общей ленте/чартах: главная — сетевой продукт.
    return const [];
  }

  /// Право на чтение аудио (READ_MEDIA_AUDIO на Android 13+). Уже выданный
  /// грант не дёргает системный диалог. Подменяемый в тестах — см. scan().
  Future<bool> Function() permissionGate = _ensurePermission;

  static Future<bool> _ensurePermission() async {
    await Permission.audio.request();
    return await Permission.audio.isGranted;
  }

  @override
  Future<PlayableStream> resolveStream(Track track) async {
    // uid сериализует путь: «local:/storage/…». Обратная распаковка — из extra,
    // если он есть, либо восстановление из uid (после перезапуска extra может
    // не доехать, а uid есть всегда).
    final extra = track.extra['localPath'] as String?;
    final path = extra ?? _pathFromUid(track.uid);
    if (path == null || !File(path).existsSync()) {
      throw SourceException(type, 'Файл не найден: он удалён или переименован');
    }
    return PlayableStream(
      uri: Uri.file(path),
      headers: const {},
    );
  }

  static String? _pathFromUid(String uid) {
    // uid = 'local:$path' (собирает Track.uid); префикс срезаем целиком.
    const prefix = 'local:';
    if (!uid.startsWith(prefix)) return null;
    return uid.substring(prefix.length);
  }

  @override
  Future<bool> downloadTo(
    Track track,
    String path, {
    void Function(int received, int total)? onProgress,
  }) async {
    // Скачивать с диска на диск незачем: файл и так локален. Если пользователь
    // явно попросил кэш — просто копируем байтами, чтобы «Скачать» не ломался.
    final extra = track.extra['localPath'] as String?;
    final src = extra ?? _pathFromUid(track.uid);
    if (src == null || !File(src).existsSync()) return false;
    try {
      await File(src).copy(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ищем файлы и в поиске по запросу (запоним что уже отсканировано).
  @override
  String toString() => 'LocalFilesSource';
}