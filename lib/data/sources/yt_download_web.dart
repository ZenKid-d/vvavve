import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// В браузере писать файл некуда, поэтому нативная загрузка всегда «не смогла».
/// Контракт `MusicSource.downloadTo` это допускает — вызывающий просто идёт
/// дальше по своим стратегиям (и на вебе тоже упрётся в отсутствие загрузок).
Future<bool> ytDownloadTo(
  YoutubeExplode yt,
  StreamInfo info,
  String path, {
  void Function(int received, int total)? onProgress,
}) async =>
    false;
