/// Ограничитель частоты по пользователю — «дырявое ведро».
///
/// Защищает не столько сервер, сколько его IP: источники банят адрес, с
/// которого летит подозрительный поток запросов, а адрес у нас один на всех, и
/// именно к нему привязаны выданные ссылки на потоки.
class RateLimiter {
  RateLimiter({this.capacity = 120, this.refillPerSecond = 6});

  /// Сколько запросов можно сделать «залпом».
  final int capacity;

  /// С какой скоростью восстанавливается право на запросы.
  final double refillPerSecond;

  final Map<String, ({double tokens, DateTime at})> _buckets = {};

  bool allow(String key) {
    final now = DateTime.now();
    final bucket = _buckets[key];
    var tokens = capacity.toDouble();

    if (bucket != null) {
      final elapsed = now.difference(bucket.at).inMilliseconds / 1000;
      tokens = bucket.tokens + elapsed * refillPerSecond;
      if (tokens > capacity) tokens = capacity.toDouble();
    }

    if (tokens < 1) {
      _buckets[key] = (tokens: tokens, at: now);
      return false;
    }
    _buckets[key] = (tokens: tokens - 1, at: now);

    // Раз в какое-то время подчищаем давно неактивных, чтобы карта не росла
    // бесконечно на долгоживущем процессе.
    if (_buckets.length > 10000) {
      _buckets.removeWhere(
          (_, b) => now.difference(b.at) > const Duration(hours: 1));
    }
    return true;
  }
}
