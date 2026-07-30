import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'doh_resolver.dart';

/// Веб-реализация сетевого обхода: обхода нет и быть не может.
///
/// В браузере ни DoH, ни HTTP-прокси клиенту недоступны — соединение открывает
/// сам браузер, а `dart:io` отсутствует. Блокировки на вебе снимает не клиент, а
/// собственный прокси-сервер (BFF), через который переписываются запросы.
/// Поэтому здесь обе фабрики просто отдают значения по умолчанию.

/// null — dio сам выберет `BrowserHttpClientAdapter`.
HttpClientAdapter? buildDohDioAdapter(DohResolver? doh, {String? proxy}) => null;

/// Обычный `YoutubeExplode`. Проксирование его запросов подключается отдельно,
/// подменой http-клиента (см. этап BFF), а не здесь.
YoutubeExplode buildYoutubeExplode(DohResolver? doh, {String? proxy}) =>
    YoutubeExplode();
