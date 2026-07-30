import 'synced_record.dart';

/// Набор записей, который умеет отдавать изменения и принимать чужие, не
/// раскрывая своего типа значения.
///
/// Благодаря этому служба синхронизации работает с лайками, плейлистами и
/// артистами одинаково и ничего не знает ни о `Track`, ни об `AlbumResult`.
abstract interface class RawSyncBucket {
  /// Записи, изменённые после [watermark], с полезной нагрузкой в JSON.
  List<SyncedRecord<Map<String, dynamic>>> dirtyRaw(int watermark);

  /// Применяет чужую запись. true — если состояние изменилось.
  bool mergeRaw(SyncedRecord<Map<String, dynamic>> incoming);

  /// Сериализованное состояние — чтобы сохранять набор, не зная его типа.
  String encode();
}
