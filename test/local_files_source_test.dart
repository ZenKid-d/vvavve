import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/data/sources/local_files_source.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/music_source.dart';

void main() {
  group('parse имени файла', () {
    test('«Артист — Название.mp3» разбирается по среднему тире', () {
      // «/» внутри имени файла на Android невозможна (сепаратор), поэтому
      // реалистичный кейс — AC-DC, а не AC/DC.
      final t = LocalFilesSource.trackFromFile(
          '/storage/emulated/0/Music/AC-DC - Hells Bells.mp3');
      expect(t.artist, 'AC-DC');
      expect(t.title, 'Hells Bells');
      expect(t.source, SourceType.local);
    });

    test('en-dash и подчёркивание тоже разделители', () {
      expect(
        LocalFilesSource.trackFromFile('/x/Aphex Twin – Xtal.flac').artist,
        'Aphex Twin',
      );
      expect(
        LocalFilesSource.trackFromFile('/x/Burial_-_Archangel.ogg').artist,
        'Burial',
      );
    });

    test('без разделителя — всё в название, артист-заглушка', () {
      final t = LocalFilesSource.trackFromFile('/x/track01.mp3');
      expect(t.artist, 'На устройстве');
      expect(t.title, 'track01');
    });

    test('uid повторяет путь через префикс и регистр сохраняет: '
        'файловая система Android case-sensitive', () {
      final t = LocalFilesSource.trackFromFile(
          '/storage/emulated/0/Music/A/Track.MP3');
      expect(t.uid, 'local:/storage/emulated/0/Music/A/Track.MP3');
      expect(
        LocalFilesSource.trackFromFile('/x/A.MP3').uid,
        isNot(
            LocalFilesSource.trackFromFile('/x/a.MP3'.toLowerCase()).uid),
      );
    });

    test('modified-время попадает в extra', () {
      final m = DateTime.parse('2026-01-02T03:04:05Z');
      final t = LocalFilesSource.trackFromFile('/x/a.mp3', modified: m);
      expect(t.extra['modifiedTs'], m.millisecondsSinceEpoch);
    });
  });

  group('скан каталогов', () {
    late Directory albumDir;
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('localfiles_test');
      // Каталог «Музыка/Артист/Альбом» — типичная структура, до неё надо
      // дойти сканом в глубину.
      albumDir = Directory('${root.path}/Music/Artist/Album')
        ..createSync(recursive: true);
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    Future<LocalFilesSource> grantedSource() async {
      final s = LocalFilesSource();
      s.permissionGate = () async => true;
      s.scanTargets = () => [Directory('${root.path}/Music')];
      return s;
    }

    test('находит аудио в глубине вложенности', () async {
      final deep = Directory('${albumDir.path}/Sub')..createSync();
      File('${deep.path}/deep song.mp3')
          .writeAsBytesSync(const [0xFF, 0xFB]);
      File('${albumDir.path}/top song.flac').writeAsBytesSync(const [0x66]);

      final s = await grantedSource();
      final tracks = await s.scan();
      expect(tracks, hasLength(2));
      expect(tracks.map((t) => t.title), contains('deep song'));
      expect(tracks.map((t) => t.title), contains('top song'));
    });

    test('скрытые каталоги и не-аудио пропускаются', () async {
      Directory('${albumDir.path}/.hidden').createSync();
      File('${Directory('${albumDir.path}/.hidden').path}/x.mp3')
          .writeAsBytesSync([1]);
      File('${albumDir.path}/cover.jpg').writeAsBytesSync([0x89, 0x50]);

      final s = await grantedSource();
      expect(await s.scan(), isEmpty);
    });

    test('отказ в праве → пусто и честно (Принцип II)', () async {
      final s = LocalFilesSource()..permissionGate = () async => false;
      expect(await s.scan(), isEmpty);
    });

    test('поиск фильтрует отсканированный кэш', () async {
      final s = await grantedSource();
      File('${albumDir.path}/best of.mp3').writeAsBytesSync([1]);
      File('${albumDir.path}/others.mp3').writeAsBytesSync([1]);
      final all = await s.scan();
      // Диагностика: если scan отдал не то, тест упадёт здесь с наглядным
      // списком имён.
      expect(all.map((t) => '${t.artist}/${t.title}').toList(),
          contains('На устройстве/best of'));
      final hit = await s.search('best', limit: 10);
      expect(hit, hasLength(1));
      expect(hit.single.title, 'best of');
    });
  });

  group('resolveStream', () {
    test('живой файл резолвится в file-URI без заголовков', () async {
      final tmp =
          await Directory.systemTemp.createTemp('lf_resolve');
      final f = File('${tmp.path}/best.mp3')..writeAsBytesSync([1]);
      final t = LocalFilesSource.trackFromFile(f.path);
      final s = LocalFilesSource();
      final stream = await s.resolveStream(t);
      expect(stream.uri, Uri.file(f.path));
      await tmp.delete(recursive: true);
    });

    test('удалённый файл → человекочитаемая ошибка, не крэш', () async {
      final t = LocalFilesSource.trackFromFile('/x/nope.mp3');
      final s = LocalFilesSource();
      await expectLater(
          s.resolveStream(t),
          throwsA(predicate(
              (e) => e is SourceException && e.toString().contains('Файл не найден'))),
      );
    });
  });
}