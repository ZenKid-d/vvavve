import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/net/net_errors.dart';

DioException _badResponse(int code, {dynamic body}) {
  final req = RequestOptions(path: '/search');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: code, data: body),
  );
}

void main() {
  group('describeNetError', () {
    test('401 — одна строка со статусом и причиной, без лекции Dio', () {
      final s = describeNetError(_badResponse(401));

      expect(s, contains('HTTP 401'));
      expect(s, contains('токен'));
      // Ровно то, что раньше попадало в журнал целиком: многострочный дамп с
      // ссылкой на MDN и НЕВЕРНОЙ расшифровкой 401 («bad syntax» — это 400).
      expect(s, isNot(contains('\n')));
      expect(s, isNot(contains('validateStatus')));
      expect(s, isNot(contains('developer.mozilla.org')));
      expect(s, isNot(contains('bad syntax')));
    });

    test('статусы без особого смысла — только код', () {
      expect(describeNetError(_badResponse(418)), 'HTTP 418');
    });

    test('429 и 5xx подписаны своими словами', () {
      expect(describeNetError(_badResponse(429)), contains('троттлинг'));
      expect(describeNetError(_badResponse(503)), contains('сбой на стороне'));
    });

    test('из JSON-тела берётся текст ошибки', () {
      final s = describeNetError(
          _badResponse(403, body: {'error': 'quota', 'message': 'нет квоты'}));
      expect(s, contains('нет квоты'));
    });

    test('вложенный error.error_msg (формат VK) тоже разбирается', () {
      final s = describeNetError(_badResponse(400, body: {
        'error': {'error_code': 5, 'error_msg': 'User authorization failed'}
      }));
      expect(s, contains('User authorization failed'));
    });

    test('HTML-страница (капча/блокировка) не тащится в журнал целиком', () {
      final html = '<html><body>${'x' * 5000}</body></html>';
      final s = describeNetError(_badResponse(403, body: html));

      expect(s, contains('html'));
      expect(s.length, lessThan(120));
      expect(s, isNot(contains('xxxxxxxxxx')));
    });

    test('длинное тело обрезается, перевод строки не проходит в журнал', () {
      final s = describeNetError(
          _badResponse(500, body: 'сбой\nстрока2\n${'y' * 500}'));

      expect(s, isNot(contains('\n')));
      expect(s.length, lessThan(200));
      expect(s, endsWith('…'));
    });

    test('сбой без ответа — DNS-блокировка распознаётся по хосту', () {
      final req = RequestOptions(path: '/search');
      final s = describeNetError(DioException(
        requestOptions: req,
        type: DioExceptionType.connectionError,
        message: "Failed host lookup: 'api-v2.soundcloud.com'",
      ));

      expect(s, contains('api-v2.soundcloud.com'));
      expect(s, contains('DNS'));
      // Маркер должен пережить переформулировку: источник кладёт этот текст в
      // сообщение SourceException, а агрегатор по нему узнаёт блокировку DNS.
      expect(isDnsBlockError(s), isTrue);
      expect(blockedHostOf(s), 'api-v2.soundcloud.com');
    });

    test('не-Dio ошибка отдаётся как есть, одной строкой', () {
      expect(describeNetError(StateError('вот так')), contains('вот так'));
      expect(describeNetError(Exception('a\nb')), isNot(contains('\n')));
    });
  });
}
