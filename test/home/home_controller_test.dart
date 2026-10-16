import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/data/recommendation_service.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
// Проверяем чистую часть главной: фильтрацию чёрного списка, дедуп по uid и
// сборку рядов. Ни сети, ни виджетов, ни Riverpod — всё, что можно сломать
// молча (выбросить весь ряд из-за одного заблокированного артиста), живёт
// именно здесь.
import 'package:roundds/features/home/home_controller.dart';

Track _t(
  String id,
  String artist, {
  String title = 'T',
  SourceType source = SourceType.youtube,
}) =>
    Track(id: id, title: title, artist: artist, source: source);

/// Предикат чёрного списка без хранилища: ровно тот контракт, который
/// ожидает [filterTracks] от `LibraryController.isArtistBlacklisted`.
bool Function(String) _blocked(List<String> names) {
  final set = names.map((e) => e.toLowerCase()).toSet();
  return (artist) => set.contains(artist.toLowerCase());
}

void main() {
  group('dedupeByUid', () {
    test('оставляет первое вхождение и сохраняет порядок', () {
      final out = dedupeByUid([
        _t('1', 'A'),
        _t('2', 'B'),
        _t('1', 'A', title: 'Другое название'),
        _t('3', 'C'),
      ]);
      expect(out.map((e) => e.id), ['1', '2', '3']);
      // Первое вхождение выигрывает: у него уже есть обложка и длительность,
      // а второй экземпляр — обычно «облегчённая» копия из другого провайдера.
      expect(out.first.title, 'T');
    });

    test('один и тот же id из разных источников — не дубли', () {
      final out = dedupeByUid([
        _t('42', 'A', source: SourceType.youtube),
        _t('42', 'A', source: SourceType.soundcloud),
      ]);
      expect(out, hasLength(2));
      expect(out.map((e) => e.source), [
        SourceType.youtube,
        SourceType.soundcloud,
      ]);
    });

    test('пустой список на входе — пустой на выходе', () {
      expect(dedupeByUid(const []), isEmpty);
    });
  });

  group('filterTracks', () {
    test('выбрасывает артиста из чёрного списка', () {
      final out = filterTracks(
        [_t('1', 'Ненавистный'), _t('2', 'Любимый')],
        _blocked(['ненавистный']),
      );
      expect(out.map((e) => e.id), ['2']);
    });

    test('регистр артиста не важен — как и в самом хранилище', () {
      final out = filterTracks([_t('1', 'Artist')], _blocked(['ARTIST']));
      expect(out, isEmpty);
    });

    test('дубликаты убираются даже если первый экземпляр заблокирован', () {
      // Регрессия на «сначала запомнили uid, потом отфильтровали»: если бы uid
      // запоминался только для прошедших чёрный список, второй (тот же самый)
      // трек проскочил бы в ленту.
      final out = filterTracks(
        [_t('1', 'Блок'), _t('1', 'Блок')],
        _blocked(['блок']),
      );
      expect(out, isEmpty);
    });

    test('порядок сохраняется, дедуп и фильтр не переставляют', () {
      final out = filterTracks(
        [_t('3', 'C'), _t('1', 'X'), _t('2', 'B'), _t('1', 'X')],
        _blocked(['X']),
      );
      expect(out.map((e) => e.id), ['3', '2']);
    });
  });

  group('filterRows — сборка рядов', () {
    test('фильтрует треки внутри ряда', () {
      final rows = filterRows(
        [
          RecoRow('Для тебя', [_t('1', 'Хороший'), _t('2', 'Плохой')]),
        ],
        _blocked(['плохой']),
      );
      expect(rows, hasLength(1));
      expect(rows.first.title, 'Для тебя');
      expect(rows.first.tracks.map((e) => e.id), ['1']);
    });

    test('выбрасывает ряд, который опустел после фильтрации', () {
      // Заголовок над «0 треков» — это враньё: пользователь видит раздел и
      // ничего по нему не находит.
      final rows = filterRows(
        [
          RecoRow('Пустой', [_t('1', 'Плохой')]),
          RecoRow('Живой', [_t('2', 'Хороший')]),
        ],
        _blocked(['плохой']),
      );
      expect(rows.map((e) => e.title), ['Живой']);
    });

    test('убирает повтор одного трека в ряде', () {
      final rows = filterRows(
        [
          RecoRow('Ряд', [_t('1', 'A'), _t('1', 'A'), _t('2', 'B')]),
        ],
        _blocked(const []),
      );
      expect(rows.single.tracks.map((e) => e.id), ['1', '2']);
    });

    test('на входе ничего — на выходе ничего', () {
      expect(filterRows(const [], _blocked(const [])), isEmpty);
      expect(
        filterRows([const RecoRow('Пустой', [])], _blocked(const [])),
        isEmpty,
      );
    });
  });

  group('hasSomethingToPlay', () {
    test('история или лайки — можно играть', () {
      expect(hasSomethingToPlay([_t('1', 'A')], const []), isTrue);
      expect(hasSomethingToPlay(const [], [_t('1', 'A')]), isTrue);
    });

    test('пустая библиотека — нечего играть', () {
      expect(hasSomethingToPlay(const [], const []), isFalse);
    });
  });

  group('greetingFor', () {
    test('по времени суток', () {
      expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Доброе утро');
      expect(greetingFor(DateTime(2026, 1, 1, 15)), 'Добрый день');
      expect(greetingFor(DateTime(2026, 1, 1, 20)), 'Добрый вечер');
      expect(greetingFor(DateTime(2026, 1, 1, 3)), 'Доброй ночи');
    });

    test('границы суток не уезжают на соседний промежуток', () {
      expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Доброе утро');
      expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Добрый день');
      expect(greetingFor(DateTime(2026, 1, 1, 18)), 'Добрый вечер');
      expect(greetingFor(DateTime(2026, 1, 1, 23)), 'Доброй ночи');
      expect(greetingFor(DateTime(2026, 1, 1, 0)), 'Доброй ночи');
    });
  });

  group('homeGenres', () {
    test('непустой и без повторов — иначе лента чипов врёт', () {
      expect(homeGenres, isNotEmpty);
      expect(homeGenres.toSet().length, homeGenres.length);
    });
  });
}
