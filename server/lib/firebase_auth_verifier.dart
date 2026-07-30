import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

/// Проверка токена Firebase — чтобы прокси не был открыт всему интернету.
///
/// Проверяется именно подпись, а не только содержимое: полезная нагрузка JWT
/// это обычный base64, и «проверка» полей без подписи означала бы, что нужный
/// токен может выписать себе кто угодно.
///
/// Ключи сервис-аккаунта не нужны — подпись проверяется по публичным
/// сертификатам Google. На сервере, соответственно, нечего красть.
class FirebaseAuthVerifier {
  FirebaseAuthVerifier(this.projectId, {http.Client? client})
      : _client = client ?? http.Client();

  final String projectId;
  final http.Client _client;

  static const _certsUrl =
      'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

  Map<String, String> _certs = const {};
  DateTime _certsFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Возвращает uid или null, если токен не годится.
  Future<String?> verify(String? authorizationHeader) async {
    final token = _bearer(authorizationHeader);
    if (token == null) return null;

    final kid = _kidOf(token);
    if (kid == null) return null;

    var cert = await _certFor(kid);
    if (cert == null) {
      // Незнакомый ключ — возможно, Google их провернул. Обновляем и пробуем ещё
      // раз, прежде чем отказывать.
      await _fetchCerts(force: true);
      cert = _certs[kid];
      if (cert == null) return null;
    }

    try {
      final jwt = JWT.verify(
        token,
        RSAPublicKey.cert(cert),
        issuer: 'https://securetoken.google.com/$projectId',
        audience: Audience.one(projectId),
      );
      final claims = jwt.payload as Map<String, dynamic>;
      final sub = claims['sub'];
      return sub is String && sub.isNotEmpty ? sub : null;
    } on JWTException {
      // Просрочен, чужой проект, поддельная подпись — наружу причину не
      // сообщаем: подсказывать подбирающему нечего.
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _certFor(String kid) async {
    await _fetchCerts();
    return _certs[kid];
  }

  Future<void> _fetchCerts({bool force = false}) async {
    if (!force &&
        DateTime.now().difference(_certsFetchedAt) < const Duration(hours: 6)) {
      return;
    }
    try {
      final r = await _client.get(Uri.parse(_certsUrl));
      if (r.statusCode == 200) {
        _certs = (jsonDecode(r.body) as Map).cast<String, String>();
        _certsFetchedAt = DateTime.now();
      }
    } catch (_) {
      // Нет связи с Google — старые ключи ещё какое-то время валидны, поэтому
      // продолжаем с тем, что есть, вместо отказа всем подряд.
    }
  }

  static String? _kidOf(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final header = jsonDecode(utf8.decode(base64Url.decode(_pad(parts[0]))))
          as Map<String, dynamic>;
      final kid = header['kid'];
      return kid is String ? kid : null;
    } catch (_) {
      return null;
    }
  }

  static String? _bearer(String? header) {
    if (header == null) return null;
    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) return null;
    final token = header.substring(prefix.length).trim();
    return token.isEmpty ? null : token;
  }

  static String _pad(String s) => s.padRight((s.length + 3) ~/ 4 * 4, '=');
}
