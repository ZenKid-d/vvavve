import 'dart:io';

export 'net_errors_common.dart';

/// true, если ошибка — недоступность DNS (хост не получил IP).
///
/// Для «сырого» [SocketException] смотрим `errno == 7`, для завёрнутых (dio
/// кладёт в `.error`, youtube_explode отдаёт `ClientException`) — текст.
bool isDnsBlockError(Object error) {
  if (error is SocketException && error.osError?.errorCode == 7) return true;
  return error.toString().contains('Failed host lookup');
}
