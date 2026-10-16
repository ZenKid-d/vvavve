import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'share_file.dart';

/// Просит пользователя выбрать JSON-файл и возвращает его содержимое.
/// null — пользователь отменил выбор.
Future<String?> pickJsonText() async {
  final file = await FilePicker.pickFile(
      type: FileType.custom, allowedExtensions: ['json']);
  if (file == null) return null;
  return utf8.decode(await file.readAsBytes());
}

/// Отдаёт текстовый файл наружу: «Поделиться» на мобильном, загрузка в браузере.
Future<void> shareTextFile(
  String content, {
  required String filename,
  required String mime,
  String? text,
}) =>
    shareBytes(Uint8List.fromList(utf8.encode(content)),
        filename: filename, mime: mime, text: text);
