import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:vvavve_bff/bff.dart';

/// Точка входа прокси. Всё, что отличает установки друг от друга, живёт в
/// переменных окружения — образ один и тот же везде.
Future<void> main(List<String> args) async {
  final env = Platform.environment;

  final projectId = env['FIREBASE_PROJECT_ID'];
  final secret = env['STREAM_SECRET'];
  final origin = env['ALLOWED_ORIGIN'];

  // Падать на старте, а не отдавать 500 на каждый запрос: пустой секрет
  // означал бы, что ссылки на поток подписывает кто угодно.
  if (projectId == null || projectId.isEmpty) {
    stderr.writeln('FIREBASE_PROJECT_ID не задан');
    exit(64);
  }
  if (secret == null || secret.length < 32) {
    stderr.writeln('STREAM_SECRET не задан или короче 32 символов');
    exit(64);
  }
  if (origin == null || origin.isEmpty) {
    stderr.writeln('ALLOWED_ORIGIN не задан (адрес веб-версии)');
    exit(64);
  }

  final bff = Bff(projectId: projectId, streamSecret: secret, origin: origin);
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(
    const Pipeline().addMiddleware(logRequests()).addHandler(bff.handler),
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('vvavve BFF слушает ${server.address.host}:${server.port}');
}
