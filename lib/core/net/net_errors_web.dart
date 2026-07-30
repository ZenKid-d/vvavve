export 'net_errors_common.dart';

/// true, если ошибка — недоступность DNS (хост не получил IP).
///
/// В браузере нет `SocketException`, поэтому остаётся проверка по тексту.
/// На вебе такой ошибки в норме и не бывает: соединение открывает браузер, а
/// сбой резолва приходит как обычная сетевая ошибка XHR.
bool isDnsBlockError(Object error) =>
    error.toString().contains('Failed host lookup');
