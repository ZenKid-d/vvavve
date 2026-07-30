import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'allowlist.dart';
import 'firebase_auth_verifier.dart';
import 'rate_limiter.dart';
import 'stream_token.dart';

/// Прокси веб-версии.
///
/// Нужен по трём независимым причинам, каждая из которых сама по себе делает
/// браузерную версию невозможной:
///  1. Источники не отдают CORS-заголовков.
///  2. Браузер запрещает JS выставлять User-Agent/Referer/Origin, а источники
///     их требуют.
///  3. Тег <audio> не умеет слать заголовки вовсе.
class Bff {
  Bff({
    required String projectId,
    required this.streamSecret,
    required this.origin,
    http.Client? client,
    FirebaseAuthVerifier? verifier,
  })  : _client = client ?? http.Client(),
        _auth = verifier ?? FirebaseAuthVerifier(projectId);

  final String streamSecret;

  /// Адрес веб-версии. Конкретный, а не `*`: ответы содержат данные,
  /// добытые под учёткой пользователя.
  final String origin;

  final http.Client _client;
  final FirebaseAuthVerifier _auth;
  final _limiter = RateLimiter();

  static const _fwdPrefix = 'x-fwd-';
  static const _streamTtl = Duration(hours: 6);

  /// Заголовки браузера, которые наверх уходить не должны: часть выдаёт наш
  /// origin, часть — наш же токен, которому там делать нечего.
  static const _stripFromClient = {
    'host',
    'origin',
    'referer',
    'authorization',
    'cookie',
    'connection',
    'content-length',
    'accept-encoding',
    'sec-fetch-mode',
    'sec-fetch-site',
    'sec-fetch-dest',
    'sec-ch-ua',
    'sec-ch-ua-mobile',
    'sec-ch-ua-platform',
  };

  Handler get handler {
    final router = Router()
      ..options('/<ignored|.*>', _preflight)
      ..get('/v1/healthz', (Request _) => Response.ok('ok'))
      ..post('/v1/sign', _sign)
      ..get('/v1/stream', _stream)
      ..all('/v1/api', _api);
    return router.call;
  }

  // --- CORS ---

  Map<String, String> get _cors => {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Headers': 'authorization,content-type,x-fwd-*',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Access-Control-Expose-Headers':
            'content-range,content-length,accept-ranges,content-type',
        // Без этого каждый POST в InnerTube тащит за собой отдельный OPTIONS —
        // ровно вдвое больше запросов.
        'Access-Control-Max-Age': '86400',
        'Vary': 'Origin',
      };

  Response _preflight(Request _) => Response(204, headers: _cors);

  // --- Общий прокси API ---

  Future<Response> _api(Request request) async {
    final uid = await _auth.verify(request.headers['authorization']);
    if (uid == null) return _deny(401, 'Нужен действующий токен');
    if (!_limiter.allow(uid)) return _deny(429, 'Слишком часто');

    final target = request.url.queryParameters['u'];
    if (target == null) return _deny(400, 'Не указан адрес');

    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme || !uri.isScheme('https')) {
      return _deny(400, 'Ожидается абсолютный https-адрес');
    }
    if (!isAllowedHost(uri.host)) return _deny(403, 'Хост не разрешён');

    try {
      final upstream = http.Request(request.method, uri)
        ..followRedirects = false
        ..headers.addAll(_upstreamHeaders(request));
      if (request.method != 'GET' && request.method != 'HEAD') {
        upstream.bodyBytes = await request.read().expand((c) => c).toList();
      }

      final response = await _client
          .send(upstream)
          .timeout(const Duration(seconds: 20));
      final body = await response.stream.toBytes();

      return Response(
        response.statusCode,
        body: body,
        headers: {
          ..._cors,
          'content-type':
              response.headers['content-type'] ?? 'application/octet-stream',
        },
      );
    } on TimeoutException {
      return _deny(504, 'Источник не ответил');
    } catch (e) {
      return _deny(502, 'Источник недоступен: $e');
    }
  }

  /// Собирает заголовки для запроса наверх: восстанавливает запрещённые
  /// браузеру (из `X-Fwd-*`) и выкидывает те, что выдали бы наш origin.
  Map<String, String> _upstreamHeaders(Request request) {
    final out = <String, String>{};
    request.headers.forEach((name, value) {
      final key = name.toLowerCase();
      if (key.startsWith(_fwdPrefix)) {
        final restored = key.substring(_fwdPrefix.length);
        if (restorableHeaders.contains(restored)) out[restored] = value;
        return;
      }
      if (_stripFromClient.contains(key)) return;
      out[key] = value;
    });
    return out;
  }

  // --- Подпись ссылки на поток ---

  /// Клиент отдаёт разрешённый адрес потока и нужные заголовки, получает
  /// короткоживущую подписанную ссылку, которую уже можно скормить `<audio>`.
  Future<Response> _sign(Request request) async {
    final uid = await _auth.verify(request.headers['authorization']);
    if (uid == null) return _deny(401, 'Нужен действующий токен');

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _deny(400, 'Ожидается JSON');
    }

    final url = body['url'] as String?;
    if (url == null) return _deny(400, 'Не указан адрес потока');
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https') || !isAllowedHost(uri.host)) {
      return _deny(403, 'Хост не разрешён');
    }

    final headers = <String, String>{
      for (final e in ((body['headers'] as Map?) ?? const {}).entries)
        '${e.key}'.toLowerCase(): '${e.value}',
    };
    final expiresAt = DateTime.now().add(_streamTtl);
    final token = StreamToken(
      url: url,
      headers: headers,
      uid: uid,
      expiresAt: expiresAt,
    ).sign(streamSecret);

    return Response.ok(
      jsonEncode({
        'url': '/v1/stream?t=${Uri.encodeComponent(token)}',
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      }),
      headers: {..._cors, 'content-type': 'application/json'},
    );
  }

  // --- Аудиопоток ---

  Future<Response> _stream(Request request) async {
    final raw = request.url.queryParameters['t'];
    if (raw == null) return _deny(400, 'Нет пропуска');

    final token = StreamToken.verify(raw, streamSecret);
    if (token == null) return _deny(403, 'Пропуск недействителен');

    final uri = Uri.parse(token.url);
    if (!isAllowedHost(uri.host)) return _deny(403, 'Хост не разрешён');

    // Range пробрасываем как есть — на нём держится перемотка. Если браузер
    // его не прислал, просим поток с начала явно: раздача googlevideo ведёт
    // себя предсказуемее с диапазоном, чем без него.
    return _fetchStream(uri, token.headers, request.headers['range'] ?? 'bytes=0-');
  }

  /// Тянет поток, при необходимости сам проходя по перенаправлениям.
  ///
  /// Отдавать редирект клиенту нельзя: браузер пошёл бы по нему напрямую,
  /// мимо прокси, и упёрся бы в CORS. Поэтому идём сами — но только внутрь
  /// списка разрешённых хостов и с ограничением на длину цепочки.
  Future<Response> _fetchStream(Uri uri, Map<String, String> headers, String range,
      {int depth = 0}) async {
    if (depth > 4) return _deny(502, 'Слишком длинная цепочка перенаправлений');
    try {
      final upstream = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll({...headers, 'range': range});

      final response = await _client.send(upstream);

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        final next = location == null ? null : uri.resolve(location);
        if (next == null || !isAllowedHost(next.host)) {
          return _deny(502, 'Перенаправление за пределы разрешённых хостов');
        }
        return _fetchStream(next, headers, range, depth: depth + 1);
      }

      return Response(
        response.statusCode,
        // Тело не буферизуем: трек может быть десятками мегабайт, а слушателей
        // много — держать их всех в памяти нельзя.
        body: response.stream,
        headers: {
          ..._cors,
          'accept-ranges': 'bytes',
          if (response.headers['content-type'] != null)
            'content-type': response.headers['content-type']!,
          if (response.headers['content-length'] != null)
            'content-length': response.headers['content-length']!,
          if (response.headers['content-range'] != null)
            'content-range': response.headers['content-range']!,
        },
      );
    } catch (e) {
      return _deny(502, 'Поток недоступен: $e');
    }
  }

  Response _deny(int status, String message) => Response(
        status,
        body: jsonEncode({'error': message}),
        headers: {..._cors, 'content-type': 'application/json'},
      );
}
