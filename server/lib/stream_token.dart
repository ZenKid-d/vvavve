import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Подписанный пропуск к аудиопотоку.
///
/// Тег `<audio>` не умеет слать заголовки, поэтому единственное место, куда
/// можно положить право на доступ, — сам адрес. Отсюда подпись: без неё
/// `/v1/stream?u=<любой адрес>` превратил бы сервер в открытый релей, а с
/// коротким сроком жизни украденная ссылка быстро протухает.
class StreamToken {
  const StreamToken({
    required this.url,
    required this.headers,
    required this.uid,
    required this.expiresAt,
  });

  /// Адрес наверху (уже проверенный по списку разрешённых хостов).
  final String url;

  /// Заголовки, которые источник требует для отдачи потока.
  final Map<String, String> headers;

  /// Кому выдан — на случай разбора логов и точечной блокировки.
  final String uid;

  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
        'u': url,
        'h': headers,
        'uid': uid,
        'exp': expiresAt.millisecondsSinceEpoch,
      };

  static StreamToken fromJson(Map<String, dynamic> j) => StreamToken(
        url: j['u'] as String,
        headers: {
          for (final e in ((j['h'] as Map?) ?? const {}).entries)
            e.key as String: '${e.value}',
        },
        uid: j['uid'] as String? ?? '',
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch((j['exp'] as num).toInt()),
      );

  String sign(String secret) {
    final payload = base64Url.encode(utf8.encode(jsonEncode(toJson())));
    final mac = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload));
    return '$payload.${base64Url.encode(mac.bytes)}';
  }

  /// Разбирает и проверяет токен. null — подпись не сошлась, срок истёк или
  /// формат не тот. Причину наружу не сообщаем: подсказывать подбирающему
  /// нечего.
  static StreamToken? verify(String token, String secret) {
    final dot = token.lastIndexOf('.');
    if (dot <= 0) return null;
    final payload = token.substring(0, dot);
    final signature = token.substring(dot + 1);

    final expected =
        Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload));
    if (!_constantTimeEquals(base64Url.encode(expected.bytes), signature)) {
      return null;
    }
    try {
      final json =
          jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      final parsed = StreamToken.fromJson(json);
      if (parsed.expiresAt.isBefore(DateTime.now())) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Сравнение за постоянное время: обычное `==` выходит из цикла на первом
  /// несовпавшем байте, и по времени ответа подпись можно подбирать побайтно.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
