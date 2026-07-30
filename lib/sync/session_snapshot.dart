import '../domain/models/track.dart';

/// Что именно переносится между устройствами под словом «сессия»: очередь,
/// место в ней и позиция внутри трека.
class SessionSnapshot {
  const SessionSnapshot({
    required this.queue,
    required this.index,
    required this.positionMs,
    required this.deviceId,
    this.deviceLabel,
    this.updatedAt = 0,
  });

  final List<Track> queue;
  final int index;
  final int positionMs;

  /// Кто записал. По нему отличаем свою же сессию от чужой — предлагать
  /// «перенести» с того же устройства бессмысленно.
  final String deviceId;

  /// Человеческая подпись для вопроса пользователю («с телефона», «из браузера»).
  final String? deviceLabel;

  final int updatedAt;

  Track? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  Duration get position => Duration(milliseconds: positionMs);

  /// Сколько треков очереди переносим.
  ///
  /// Очередь бывает бесконечной (режим радио докручивает её на ходу), а
  /// документ в облаке ограничен по размеру, и писать его надо часто. Окна
  /// вокруг текущего трека достаточно: остальное на другом устройстве
  /// докрутится тем же движком волны.
  static const int windowSize = 100;

  /// Обрезает очередь окном вокруг текущего трека, сохраняя позицию индекса.
  SessionSnapshot windowed() {
    if (queue.length <= windowSize) return this;
    const half = windowSize ~/ 2;
    var start = index - half;
    if (start < 0) start = 0;
    var end = start + windowSize;
    if (end > queue.length) {
      end = queue.length;
      start = end - windowSize;
    }
    return SessionSnapshot(
      queue: queue.sublist(start, end),
      index: index - start,
      positionMs: positionMs,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      updatedAt: updatedAt,
    );
  }

  /// В облако едет очищенный вид трека: рабочее состояние источников
  /// (протухающие ссылки) переносить и бессмысленно, и дорого.
  Map<String, dynamic> toJson() => {
        'queue': [for (final t in queue) t.toSyncJson()],
        'index': index,
        'positionMs': positionMs,
        'deviceId': deviceId,
        if (deviceLabel != null) 'deviceLabel': deviceLabel,
      };

  static SessionSnapshot fromJson(Map<String, dynamic> j, {int updatedAt = 0}) =>
      SessionSnapshot(
        queue: [
          for (final e in (j['queue'] as List? ?? const []))
            Track.fromJson((e as Map).cast<String, dynamic>()),
        ],
        index: (j['index'] as num?)?.toInt() ?? 0,
        positionMs: (j['positionMs'] as num?)?.toInt() ?? 0,
        deviceId: j['deviceId'] as String? ?? '',
        deviceLabel: j['deviceLabel'] as String?,
        updatedAt: updatedAt,
      );
}
