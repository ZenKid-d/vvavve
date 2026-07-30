/// Утилиты распознавания сетевых ошибок «хост не резолвится» — типичная картина
/// при блокировке/троттлинге у провайдера или неверном DNS у VPN:
/// `SocketException: Failed host lookup: '<host>' (OS Error: ..., errno = 7)`.
///
/// Такая ошибка приходит завёрнутой по-разному: `DioException` (dio) оборачивает
/// её в `.error`, а `youtube_explode_dart` (через package:http) — в
/// `ClientException`. Чтобы не тащить зависимости обоих пакетов, сводим проверку
/// к тексту сообщения (в нём всегда есть `Failed host lookup`), а для «сырого»
/// `SocketException` дополнительно смотрим `errno == 7` — это возможно только в
/// io-реализации, поэтому файл разделён по платформам.
library;

export 'net_errors_web.dart' if (dart.library.io) 'net_errors_io.dart';
