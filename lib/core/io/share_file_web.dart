import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Отдаёт файл наружу в браузере.
///
/// Временного файла на диске нет и быть не может, поэтому байты уходят прямо
/// из памяти. Дальше решает браузер: где есть Web Share API с файлами (Chrome,
/// мобильные) — откроется системный диалог, иначе share_plus сохранит файл
/// загрузкой.
Future<void> shareBytes(
  Uint8List bytes, {
  required String filename,
  required String mime,
  String? text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: filename, mimeType: mime)],
      text: text,
      // Без имени файла браузерная загрузка сохранит его как «download».
      fileNameOverrides: [filename],
    ),
  );
}
