import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Отдаёт файл наружу через системный «Поделиться».
///
/// Байты сначала кладутся во временный файл: Android-приёмники ждут именно
/// файл по пути (content-uri), а не поток в памяти.
Future<void> shareBytes(
  Uint8List bytes, {
  required String filename,
  required String mime,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path, mimeType: mime)], text: text),
  );
}
