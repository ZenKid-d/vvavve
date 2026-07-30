import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/sync/sync_clock.dart';
import 'package:roundds/sync/synced_record.dart';
import 'package:roundds/sync/synced_set.dart';

/// Простое значение вместо Track — тесты про слияние, а не про модель.
class _Item {
  const _Item(this.id, this.title);
  final String id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
  static _Item fromJson(Map<String, dynamic> j) =>
      _Item(j['id'] as String, j['title'] as String);
}

SyncedSet<_Item> _set({String? device}) => SyncedSet<_Item>(
      encode: (v) => v.toJson(),
      decode: _Item.fromJson,
      deviceId: device,
    );

void main() {
  group('SyncedSet', () {
    test('хранит значения и отдаёт новые сверху', () {
      final s = _set();
      s.upsert('a', const _Item('a', 'первый'));
      s.upsert('b', const _Item('b', 'второй'));

      expect(s.values.map((e) => e.id), ['b', 'a']);
      expect(s.contains('a'), isTrue);
      expect(s['b']?.title, 'второй');
      expect(s.length, 2);
    });

    test('удаление оставляет надгробие, а не пустоту', () {
      final s = _set();
      s.upsert('a', const _Item('a', 'раз'));
      s.remove('a');

      expect(s.contains('a'), isFalse);
      expect(s.values, isEmpty);
      expect(s.length, 0);
      // Запись осталась — иначе другому устройству нечего было бы применить.
      expect(s.records.where((r) => r.key == 'a' && r.deleted), hasLength(1));
    });

    test('слияние: побеждает более поздняя правка', () {
      final s = _set();
      s.upsert('a', const _Item('a', 'локальный'));
      final localAt = s.records.first.updatedAt;

      final older = SyncedRecord<_Item>(
          key: 'a', value: const _Item('a', 'старый'), updatedAt: localAt - 100);
      expect(s.mergeRemote(older), isFalse, reason: 'старое не должно побеждать');
      expect(s['a']?.title, 'локальный');

      final newer = SyncedRecord<_Item>(
          key: 'a', value: const _Item('a', 'новый'), updatedAt: localAt + 100);
      expect(s.mergeRemote(newer), isTrue);
      expect(s['a']?.title, 'новый');
    });

    test('удалённое на другом устройстве не воскресает', () {
      final s = _set();
      s.upsert('a', const _Item('a', 'раз'));
      final at = s.records.first.updatedAt;

      s.mergeRemote(
          SyncedRecord<_Item>(key: 'a', updatedAt: at + 10, deleted: true));
      expect(s.contains('a'), isFalse);

      // Приехала старая версия «жив» — не должна отменить удаление.
      s.mergeRemote(SyncedRecord<_Item>(
          key: 'a', value: const _Item('a', 'раз'), updatedAt: at + 5));
      expect(s.contains('a'), isFalse);
    });

    test('ничья по времени разрешается одинаково на обоих устройствах', () {
      final a = _set(device: 'aaa');
      final b = _set(device: 'bbb');

      const at = 1800000000000;
      const fromA = SyncedRecord<_Item>(
          key: 'x', value: _Item('x', 'от A'), updatedAt: at, origin: 'aaa');
      const fromB = SyncedRecord<_Item>(
          key: 'x', value: _Item('x', 'от B'), updatedAt: at, origin: 'bbb');

      a..mergeRemote(fromA)..mergeRemote(fromB);
      b..mergeRemote(fromB)..mergeRemote(fromA);

      // Порядок применения разный, результат обязан совпасть.
      expect(a['x']?.title, b['x']?.title);
      expect(a['x']?.title, 'от B');
    });

    test('грязными считаются записи новее водяного знака', () {
      final s = _set();
      s.upsert('a', const _Item('a', 'раз'));
      final watermark = s.records.first.updatedAt;
      s.upsert('b', const _Item('b', 'два'));
      s.remove('a');

      final dirty = s.dirtySince(watermark);
      expect(dirty.map((r) => r.key).toSet(), {'a', 'b'});
      // Надгробие тоже обязано уехать.
      expect(dirty.firstWhere((r) => r.key == 'a').deleted, isTrue);
      expect(s.dirtySince(SyncClock.now()), isEmpty);
    });

    test('кодирование v2 переживает круговой рейс', () {
      final s = _set(device: 'dev1');
      s.upsert('a', const _Item('a', 'раз'));
      s.upsert('b', const _Item('b', 'два'));
      s.remove('b');

      final restored = _set();
      expect(restored.decodeV2(s.encode()), isTrue);
      expect(restored.values.map((e) => e.id), ['a']);
      expect(restored.records.firstWhere((r) => r.key == 'b').deleted, isTrue);
      expect(restored.records.first.origin, 'dev1');
    });

    test('старый формат распознаётся как не-v2', () {
      final s = _set();
      expect(s.decodeV2('[{"id":"a","title":"раз"}]'), isFalse);
    });

    test('миграция v1 сохраняет прежний порядок', () {
      final s = _set();
      s.decodeV1(
        const [_Item('a', 'верхний'), _Item('b', 'средний'), _Item('c', 'нижний')],
        (i) => i.id,
        stampedAt: 1800000000000,
      );

      // В v1 порядок нёс смысл: что было сверху — сверху и осталось.
      expect(s.values.map((e) => e.id), ['a', 'b', 'c']);
      expect(s.length, 3);
    });

    test('сборка надгробий не трогает живые записи', () {
      final s = _set();
      s.upsert('живой', const _Item('живой', 'тут'));
      s.remove('старый');
      final cutoff = SyncClock.now() + 1;

      s.gcTombstones(before: cutoff);
      expect(s.contains('живой'), isTrue);
      expect(s.records.where((r) => r.key == 'старый'), isEmpty);
    });
  });

  group('SyncClock', () {
    test('метки строго возрастают даже при откате часов', () {
      final a = SyncClock.now();
      // Как будто часы прыгнули далеко вперёд, а затем вернулись назад.
      SyncClock.seen(DateTime.now().millisecondsSinceEpoch + 60000);
      final b = SyncClock.now();
      final c = SyncClock.now();

      expect(b, greaterThan(a));
      expect(c, greaterThan(b));
    });
  });
}
