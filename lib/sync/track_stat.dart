import '../domain/models/track.dart';

/// Счётчик прослушиваний трека — отдельно по каждому устройству.
///
/// Одного числа недостаточно: устройство A синхронизировало 5, B подтянуло их
/// и добавило свои 3 → 8, A подтянуло 8 и снова добавило свои 5 → 13. Так
/// счётчик разъезжается при каждом обмене. Поэтому каждое устройство пишет
/// только свой ключ, а показываем сумму — такой счётчик сходится сам, без
/// какой-либо координации между устройствами.
class TrackStat {
  const TrackStat({required this.track, required this.counts});

  final Track track;

  /// deviceId → сколько прослушиваний насчитало это устройство.
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (sum, c) => sum + c);

  TrackStat increment(String deviceId, [int by = 1]) => TrackStat(
        track: track,
        counts: {...counts, deviceId: (counts[deviceId] ?? 0) + by},
      );

  /// Слияние счётчиков: по каждому устройству берём большее значение.
  /// Складывать нельзя — та же запись, приехавшая дважды, удвоила бы счёт.
  TrackStat mergeWith(TrackStat other) {
    final merged = <String, int>{...counts};
    other.counts.forEach((device, count) {
      final mine = merged[device] ?? 0;
      merged[device] = count > mine ? count : mine;
    });
    return TrackStat(track: other.track, counts: merged);
  }

  Map<String, dynamic> toJson() => {'track': track.toJson(), 'c': counts};

  static TrackStat fromJson(Map<String, dynamic> j) => TrackStat(
        track: Track.fromJson((j['track'] as Map).cast<String, dynamic>()),
        counts: {
          for (final e in ((j['c'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
      );
}
