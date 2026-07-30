import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/diagnostics.dart';

/// Нативная потоковая загрузка через youtube_explode: сам качает аудио
/// чанками с корректными заголовками. Простой HTTP-GET по googlevideo-ссылке
/// часто отдаёт 403 (плеер играет ranged-стримингом, а полный GET — нет),
/// поэтому для скачивания YouTube этот путь надёжнее.
Future<bool> ytDownloadTo(
  YoutubeExplode yt,
  StreamInfo info,
  String path, {
  void Function(int received, int total)? onProgress,
}) async {
  IOSink? sink;
  try {
    final total = info.size.totalBytes;
    sink = File(path).openWrite();
    var received = 0;
    await for (final chunk in yt.videos.streamsClient.get(info)) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received, total);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    return true;
  } catch (e, st) {
    // Не смогли — подчистим частичный файл и отдадим управление dio-пути.
    // Логируем причину (раньше пустой catch скрывал, почему загрузка упала).
    Diagnostics.instance
        .warn('youtube', 'downloadTo через yt_explode упал: $e\n$st');
    try {
      await sink?.close();
    } catch (_) {}
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    return false;
  }
}
