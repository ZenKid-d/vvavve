/// Фасад «Управления памятью»: реализация выбирается по платформе.
///
/// `dirSize(Directory)` есть только в io-реализации — тип из dart:io в общей
/// сигнатуре появиться не может.
library;

export 'storage_web.dart' if (dart.library.io) 'storage_io.dart';
