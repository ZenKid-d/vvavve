import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:vvavve_bff/allowlist.dart';
import 'package:vvavve_bff/bff.dart';
import 'package:vvavve_bff/firebase_auth_verifier.dart';
import 'package:vvavve_bff/stream_token.dart';

/// Подменяет проверку токена: настоящая ходит к Google за ключами, а нас здесь
/// интересует поведение прокси, а не криптография (её проверяет свой тест).
class _FakeVerifier implements FirebaseAuthVerifier {
  _FakeVerifier(this.uid);
  final String? uid;

  @override
  Future<String?> verify(String? header) async =>
      header == 'Bearer good' ? uid : null;

  @override
  String get projectId => 'test';
}

const _secret = 'секрет-достаточной-длины-для-подписи-32+';

Bff _bff({http.Client? client, String? uid = 'user-1'}) => Bff(
      projectId: 'test',
      streamSecret: _secret,
      origin: 'https://example.org',
      client: client ?? MockClient((_) async => http.Response('ok', 200)),
      verifier: _FakeVerifier(uid),
    );

Request _get(String path, {Map<String, String>? headers}) =>
    Request('GET', Uri.parse('http://localhost$path'), headers: headers);

void main() {
  group('Список разрешённых хостов', () {
    test('пропускает источники и их раздачу', () {
      expect(isAllowedHost('api-v2.soundcloud.com'), isTrue);
      expect(isAllowedHost('rr3---sn-4g5e6nez.googlevideo.com'), isTrue);
      expect(isAllowedHost('cf-media.sndcdn.com'), isTrue);
    });

    test('не пропускает всё остальное', () {
      expect(isAllowedHost('example.com'), isFalse);
      expect(isAllowedHost('evil.org'), isFalse);
      // Подделка под разрешённый домен: суффикс проверяется с точкой.
      expect(isAllowedHost('googlevideo.com.evil.org'), isFalse);
      expect(isAllowedHost('notsoundcloud.com'), isFalse);
    });
  });

  group('Пропуск к потоку', () {
    test('переживает круговой рейс', () {
      final token = StreamToken(
        url: 'https://cf-media.sndcdn.com/track.mp3',
        headers: const {'user-agent': 'vvavve'},
        uid: 'user-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ).sign(_secret);

      final parsed = StreamToken.verify(token, _secret);
      expect(parsed?.url, 'https://cf-media.sndcdn.com/track.mp3');
      expect(parsed?.headers['user-agent'], 'vvavve');
    });

    test('подделанная подпись не проходит', () {
      final token = StreamToken(
        url: 'https://cf-media.sndcdn.com/track.mp3',
        headers: const {},
        uid: 'user-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ).sign(_secret);

      expect(StreamToken.verify(token, 'другой-секрет-достаточной-длины-32+'),
          isNull);
      // Подмена адреса внутри полезной нагрузки ломает подпись.
      final tampered = token.replaceFirst(token[0], token[0] == 'a' ? 'b' : 'a');
      expect(StreamToken.verify(tampered, _secret), isNull);
    });

    test('просроченный пропуск не проходит', () {
      final token = StreamToken(
        url: 'https://cf-media.sndcdn.com/track.mp3',
        headers: const {},
        uid: 'user-1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ).sign(_secret);

      expect(StreamToken.verify(token, _secret), isNull);
    });
  });

  group('Прокси API', () {
    test('без токена — 401', () async {
      final r = await _bff().handler(_get('/v1/api?u=https://lrclib.net/x'));
      expect(r.statusCode, 401);
    });

    test('неразрешённый хост — 403', () async {
      final r = await _bff().handler(_get('/v1/api?u=https://evil.org/x',
          headers: {'authorization': 'Bearer good'}));
      expect(r.statusCode, 403);
    });

    test('восстанавливает запрещённые браузеру заголовки', () async {
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response('{}', 200);
      });

      final r = await _bff(client: client).handler(_get(
        '/v1/api?u=https://music.youtube.com/youtubei/v1/search',
        headers: {
          'authorization': 'Bearer good',
          'x-fwd-user-agent': 'vvavve/1.0',
          'x-fwd-referer': 'https://music.youtube.com/',
          'x-fwd-origin': 'https://music.youtube.com',
        },
      ));

      expect(r.statusCode, 200);
      expect(seen.headers['user-agent'], 'vvavve/1.0');
      expect(seen.headers['referer'], 'https://music.youtube.com/');
      expect(seen.headers['origin'], 'https://music.youtube.com');
      // Наш собственный токен наверх уходить не должен.
      expect(seen.headers.containsKey('authorization'), isFalse);
    });

    test('произвольные заголовки по просьбе клиента не пробрасываются',
        () async {
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response('{}', 200);
      });

      await _bff(client: client).handler(_get(
        '/v1/api?u=https://lrclib.net/api/get',
        headers: {
          'authorization': 'Bearer good',
          'x-fwd-x-admin-secret': 'нельзя',
        },
      ));

      expect(seen.headers.containsKey('x-admin-secret'), isFalse);
    });

    test('отвечает с CORS для своего origin', () async {
      final r = await _bff().handler(_get('/v1/api?u=https://lrclib.net/x',
          headers: {'authorization': 'Bearer good'}));
      expect(r.headers['access-control-allow-origin'], 'https://example.org');
    });

    test('preflight кэшируется', () async {
      final r = await _bff().handler(
          Request('OPTIONS', Uri.parse('http://localhost/v1/api')));
      expect(r.statusCode, 204);
      expect(r.headers['access-control-max-age'], '86400');
    });
  });

  group('Подпись потока', () {
    test('выдаёт ссылку только на разрешённый хост', () async {
      final bff = _bff();
      final ok = await bff.handler(Request(
        'POST',
        Uri.parse('http://localhost/v1/sign'),
        headers: {'authorization': 'Bearer good'},
        body: jsonEncode({'url': 'https://cf-media.sndcdn.com/t.mp3'}),
      ));
      expect(ok.statusCode, 200);
      expect(jsonDecode(await ok.readAsString())['url'],
          startsWith('/v1/stream?t='));

      final denied = await bff.handler(Request(
        'POST',
        Uri.parse('http://localhost/v1/sign'),
        headers: {'authorization': 'Bearer good'},
        body: jsonEncode({'url': 'https://evil.org/t.mp3'}),
      ));
      expect(denied.statusCode, 403);
    });
  });

  group('Поток', () {
    test('пробрасывает Range и отдаёт 206', () async {
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        // Байты, а не строка: тело аудио бинарное, и http.Response со строкой
        // попытался бы закодировать его latin1.
        return http.Response.bytes(const [1, 2, 3, 4], 206, headers: {
          'content-range': 'bytes 100-199/1000',
          'content-type': 'audio/mpeg',
        });
      });

      final token = StreamToken(
        url: 'https://cf-media.sndcdn.com/t.mp3',
        headers: const {'user-agent': 'vvavve'},
        uid: 'user-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ).sign(_secret);

      final r = await _bff(client: client).handler(_get(
        '/v1/stream?t=${Uri.encodeComponent(token)}',
        headers: {'range': 'bytes=100-199'},
      ));

      expect(r.statusCode, 206);
      expect(seen.headers['range'], 'bytes=100-199');
      expect(seen.headers['user-agent'], 'vvavve');
      expect(r.headers['content-range'], 'bytes 100-199/1000');
      expect(r.headers['accept-ranges'], 'bytes');
    });

    test('без пропуска не отдаёт ничего', () async {
      final r = await _bff().handler(_get('/v1/stream?t=подделка'));
      expect(r.statusCode, 403);
    });

    test('перенаправление за пределы списка обрывается', () async {
      final client = MockClient((req) async => http.Response('', 302,
          headers: {'location': 'https://evil.org/leak'}));

      final token = StreamToken(
        url: 'https://cf-media.sndcdn.com/t.mp3',
        headers: const {},
        uid: 'user-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ).sign(_secret);

      final r = await _bff(client: client)
          .handler(_get('/v1/stream?t=${Uri.encodeComponent(token)}'));
      expect(r.statusCode, 502);
    });
  });
}
