import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/data/sources/soundcloud_source.dart';
import 'package:roundds/domain/music_source.dart';

/// Публичный client_id SoundCloud периодически отзывают, а мы держим его в
/// prefs между запусками. С момента отзыва каждый запрос отвечал 401 — и
/// пользователь видел «Ошибка поиска» до тех пор, пока сам не находил кнопку
/// «обновить client_id» в Настройках. Здесь проверяется автоматический путь:
/// 401 → перевыпуск id → повтор запроса. Сети нет — подменён адаптер Dio.
void main() {
  // Настоящие client_id SoundCloud — 32 буквенно-цифровых символа, и код ищет
  // их именно так ([A-Za-z0-9]{20,}). Подчёркивания в фикстуре ломали разбор:
  // страница скачивалась, id в ней «не находился», и проверка падала на
  // «не удалось получить client_id» — не потому, что перевыпуск не работает.
  const staleId = 'STALEclientID00000000000000';
  const freshId = 'FRESHclientID11111111111111';

  const discover = 'soundcloud.com/discover';
  const scriptUrl = 'https://a-v2.sndcdn.com/assets/app-1.js';
  const searchPath = '/search/tracks';

  final trackJson = {
    'collection': [
      {
        'kind': 'track',
        'id': 7,
        'title': "Why'd You Only Call Me When You're High?",
        'user': {'id': 1, 'username': 'Arctic Monkeys'},
        'media': {'transcodings': <Map>[]},
      }
    ]
  };

  late _FakeAdapter adapter;
  late SoundcloudSource sc;
  late List<String> saved;

  setUp(() {
    adapter = _FakeAdapter();
    sc = SoundcloudSource(Dio()..httpClientAdapter = adapter,
        cachedClientId: staleId);
    saved = [];
    sc.onClientIdRefreshed = saved.add;

    adapter
      ..onGet(discover,
          (_) => _html('<html><script src="$scriptUrl"></script></html>'))
      ..onGet(scriptUrl, (_) => _html('var x={client_id:"$freshId"};'));
  });

  /// Отозванный id — 401, свежий — нормальная выдача.
  void serveSearchByClientId() => adapter.onGet(
        searchPath,
        (o) => o.queryParameters['client_id'] == freshId
            ? _json(trackJson)
            : _status(401),
      );

  test('401 на поиске → client_id перевыпускается, запрос повторяется',
      () async {
    serveSearchByClientId();

    final tracks = await sc.search('arctic monkeys', limit: 5);

    expect(tracks, hasLength(1));
    expect(tracks.first.artist, 'Arctic Monkeys');
    expect(sc.clientId, freshId);
    // Свежий id уходит наружу (в prefs) — иначе следующий холодный старт
    // снова начнётся с отозванного.
    expect(saved, [freshId]);
    expect(adapter.hits(discover), 1);
    expect(adapter.hits(searchPath), 2); // исходный + повтор
  });

  test('параллельные запросы перевыпускают client_id один раз', () async {
    serveSearchByClientId();

    final results =
        await Future.wait([sc.search('a'), sc.search('b'), sc.search('c')]);

    expect(results.every((r) => r.length == 1), isTrue);
    // Три 401 подряд не должны обернуться тремя скачиваниями /discover.
    expect(adapter.hits(discover), 1);
    expect(saved, [freshId]);
  });

  test('401 и со свежим id — ошибка наружу, без второго перевыпуска', () async {
    adapter.onGet(searchPath, (_) => _status(401));

    await expectLater(
        sc.search('arctic monkeys'), throwsA(isA<SourceException>()));

    expect(adapter.hits(discover), 1);
    expect(adapter.hits(searchPath), 2); // исходный + один повтор, не цикл
  });

  test('403 (гео-блок/Go+) client_id не перевыпускает', () async {
    adapter.onGet(searchPath, (_) => _status(403));

    await expectLater(
        sc.search('arctic monkeys'), throwsA(isA<SourceException>()));

    expect(adapter.hits(discover), 0);
    expect(sc.clientId, staleId);
    expect(saved, isEmpty);
  });
}

ResponseBody _json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _html(String body) => ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );

ResponseBody _status(int code) => ResponseBody.fromString(
      '{}',
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Подменённый транспорт Dio: маршруты по подстроке URL + счётчик обращений.
class _FakeAdapter implements HttpClientAdapter {
  final _routes = <String, ResponseBody Function(RequestOptions)>{};
  final _hits = <String, int>{};

  void onGet(String urlPart, ResponseBody Function(RequestOptions) reply) =>
      _routes[urlPart] = reply;

  int hits(String urlPart) => _hits[urlPart] ?? 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final url = options.uri.toString();
    for (final e in _routes.entries) {
      if (url.contains(e.key)) {
        _hits[e.key] = (_hits[e.key] ?? 0) + 1;
        return e.value(options);
      }
    }
    throw StateError('неожиданный запрос: $url');
  }

  @override
  void close({bool force = false}) {}
}
