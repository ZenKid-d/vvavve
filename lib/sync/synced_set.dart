import 'dart:convert';

import 'sync_clock.dart';
import 'synced_record.dart';

/// Множество записей, пригодное к слиянию между устройствами.
///
/// Заменяет собой «список в JSON-блобе»: у каждой записи есть метка времени и
/// признак удаления, поэтому две копии одного множества сходятся независимо от
/// порядка и задержек — побеждает более поздняя правка (LWW).
///
/// Порядок [values] — по убыванию `updatedAt`. Это ровно то, что делал старый
/// код (`insert(0, …)` — новое сверху), но не зависит от того, на каком
/// устройстве правка сделана.
class SyncedSet<T> {
  SyncedSet({
    required Map<String, dynamic> Function(T value) encode,
    required T Function(Map<String, dynamic> json) decode,
    this.deviceId,
  })  : _encode = encode,
        _decode = decode;

  final Map<String, dynamic> Function(T value) _encode;
  final T Function(Map<String, dynamic> json) _decode;

  /// Кто вносит правки на этом устройстве — попадает в записи и разрешает
  /// ничьи по времени. null допустим (тесты, старые данные).
  String? deviceId;

  final Map<String, SyncedRecord<T>> _byKey = {};

  /// Живые значения, новые сверху.
  List<T> get values {
    final live = _byKey.values.where((r) => !r.deleted && r.value != null).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final r in live) r.value as T];
  }

  /// Живые записи (с метаданными) — нужны отправщику и тестам.
  Iterable<SyncedRecord<T>> get records => _byKey.values;

  int get length => _byKey.values.where((r) => !r.deleted).length;

  bool contains(String key) {
    final r = _byKey[key];
    return r != null && !r.deleted;
  }

  T? operator [](String key) {
    final r = _byKey[key];
    return r == null || r.deleted ? null : r.value;
  }

  /// Добавляет или обновляет значение. Возвращает метку времени правки.
  int upsert(String key, T value) {
    final at = SyncClock.now();
    _byKey[key] = SyncedRecord<T>(
      key: key,
      value: value,
      updatedAt: at,
      origin: deviceId,
    );
    return at;
  }

  /// Удаляет — оставляя надгробие, иначе правка не доедет до других устройств.
  int remove(String key) {
    final at = SyncClock.now();
    final existing = _byKey[key];
    _byKey[key] = existing?.tombstone(at, origin: deviceId) ??
        SyncedRecord<T>(key: key, updatedAt: at, deleted: true, origin: deviceId);
    return at;
  }

  /// Применяет запись, приехавшую извне. true — если она победила локальную.
  bool mergeRemote(SyncedRecord<T> incoming) {
    SyncClock.seen(incoming.updatedAt);
    final local = _byKey[incoming.key];
    if (local != null && !local.losesTo(incoming)) return false;
    _byKey[incoming.key] = incoming;
    return true;
  }

  /// Записи, изменённые после [watermark] — то, что ещё не отправлено.
  List<SyncedRecord<T>> dirtySince(int watermark) =>
      _byKey.values.where((r) => r.updatedAt > watermark).toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  /// Убирает старые надгробия: своё дело они уже сделали, а место занимают.
  /// Порог должен быть заведомо больше, чем устройство может пролежать
  /// офлайн, — иначе удаление «забудется» и запись воскреснет.
  void gcTombstones({required int before}) =>
      _byKey.removeWhere((_, r) => r.deleted && r.updatedAt < before);

  String encode() => jsonEncode({
        'v': 2,
        'items': [for (final r in _byKey.values) r.toJson(_encode)],
      });

  /// Читает формат v2. Возвращает false, если это не он (значит — старый v1).
  bool decodeV2(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map || data['v'] != 2) return false;
    _byKey.clear();
    for (final e in (data['items'] as List? ?? const [])) {
      final r = SyncedRecord.fromJson<T>((e as Map).cast<String, dynamic>(), _decode);
      SyncClock.seen(r.updatedAt);
      _byKey[r.key] = r;
    }
    return true;
  }

  /// Переносит старый список (v1) в записи.
  ///
  /// Метки времени расставляются убывающими от [stampedAt] по позиции: в v1
  /// порядок нёс смысл («новое сверху»), но времени правки не существовало, а
  /// одинаковые метки схлопнули бы порядок в произвольный.
  void decodeV1(Iterable<T> items, String Function(T value) keyOf,
      {required int stampedAt}) {
    _byKey.clear();
    var i = 0;
    for (final item in items) {
      final key = keyOf(item);
      final at = stampedAt - i;
      _byKey[key] = SyncedRecord<T>(
        key: key,
        value: item,
        updatedAt: at,
        origin: deviceId,
      );
      i++;
    }
    SyncClock.seen(stampedAt);
  }
}
