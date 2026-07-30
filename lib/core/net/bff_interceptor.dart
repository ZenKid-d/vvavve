import 'package:dio/dio.dart';

import 'bff.dart';

/// Переписывает запросы источников на прокси — в браузере.
///
/// Ставится один раз в [buildAppDio], поэтому ни один из четырёх источников не
/// знает о существовании прокси: на Android перехватчик не устанавливается
/// вовсе, и сетевой путь там ровно такой же, как был.
class BffInterceptor extends Interceptor {
  BffInterceptor(this.idToken);

  /// Токен Firebase — прокси проверяет его подпись, иначе он был бы открытым
  /// релеем. Функция, а не строка: токен живёт час и обновляется.
  final Future<String?> Function() idToken;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final absolute = options.uri.toString();
    // Уже проксированные (и служебные) не трогаем.
    if (absolute.startsWith(kBffUrl)) return handler.next(options);

    final headers = <String, dynamic>{};
    options.headers.forEach((name, value) {
      if (forbiddenInBrowser.contains(name.toLowerCase())) {
        // Браузер молча выкинет такой заголовок, поэтому отправляем его под
        // другим именем — прокси вернёт исходное.
        headers['X-Fwd-$name'] = value;
      } else {
        headers[name] = value;
      }
    });

    final token = await idToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    options
      ..path = proxiedApiUrl(absolute)
      ..queryParameters = const {} // параметры уже внутри переписанного адреса
      ..headers = headers;

    handler.next(options);
  }
}
