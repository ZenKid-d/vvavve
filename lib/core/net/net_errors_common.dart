import 'dart:convert';

import 'package:dio/dio.dart';

/// Имя недоступного хоста из сообщения об ошибке (для диагностики), напр.
/// `Failed host lookup: 'api-v2.soundcloud.com'` → `api-v2.soundcloud.com`.
/// null — если в тексте хоста нет.
///
/// Чистая работа со строкой, одинаковая на всех платформах.
String? blockedHostOf(Object error) {
  final m =
      RegExp("Failed host lookup: '([^']+)'").firstMatch(error.toString());
  return m?.group(1);
}

/// Короткое ОДНОСТРОЧНОЕ описание сетевого сбоя для журнала диагностики.
///
/// `DioException.toString()` печатает двенадцать строк: шаблонную лекцию про
/// `validateStatus`, ссылку на MDN и расшифровку статуса из своей таблицы —
/// причём неверную (для 401 там «the request contains bad syntax», текст 400).
/// В журнале на 400 записей одна такая простыня вытесняет десяток полезных
/// строк, а пользователю в баг-репорте показывает «сломалось приложение» там,
/// где просто протух токен. Поэтому в лог идёт статус + суть, а не дамп.
String describeNetError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code != null) {
      final hint = httpHint(code);
      final body = _briefBody(e.response?.data);
      return 'HTTP $code${hint.isEmpty ? '' : ' ($hint)'}'
          '${body.isEmpty ? '' : ': $body'}';
    }
    // ВАЖНО: текст `Failed host lookup: '<host>'` сохраняем дословно. Это не
    // косметика, а маркер: [isDnsBlockError]/[blockedHostOf] узнают блокировку
    // DNS по тексту ошибки — в том числе у SourceException, в сообщение
    // которого источник вкладывает результат этой функции. Перефразируешь —
    // агрегатор перестанет распознавать блокировку и советовать DoH.
    final host = blockedHostOf(e);
    if (host != null) {
      return "Failed host lookup: '$host' — DNS/блокировка провайдера";
    }
    final m = e.message;
    return _clip(m == null || m.isEmpty ? e.type.name : m);
  }
  return _clip('$e');
}

/// Смысл HTTP-статуса своими словами — то, что в этом приложении реально стоит
/// за кодом. Пусто, если добавить нечего (статус говорит сам за себя).
String httpHint(int code) {
  if (code == 401 || code == 403) {
    return 'нет доступа: ключ/токен недействителен или истёк';
  }
  if (code == 404) return 'не найдено';
  if (code == 429) return 'слишком много запросов — троттлинг';
  if (code >= 500) return 'сбой на стороне сервиса';
  return '';
}

/// Тело ответа одной строкой: из JSON вытаскиваем текст ошибки, HTML-страницу
/// (типичный ответ капчи/блокировки) не тащим в лог целиком.
String _briefBody(dynamic data) {
  if (data == null) return '';
  dynamic body = data;
  if (body is String) {
    final s = body.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('<')) return '(html ${s.length} симв.)';
    try {
      body = jsonDecode(s);
    } catch (_) {
      return _clip(s, 120);
    }
  }
  if (body is Map) {
    final err = body['error'];
    if (err is Map) {
      final msg = err['error_msg'] ?? err['message'] ?? err['status'];
      if (msg != null) return _clip('$msg', 120);
    }
    final msg = body['message'] ?? body['error_description'] ?? body['error'];
    if (msg != null) return _clip('$msg', 120);
  }
  return _clip('$body', 120);
}

String _clip(String s, [int max = 160]) {
  final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length > max ? '${one.substring(0, max)}…' : one;
}
