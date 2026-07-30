import 'synced_record.dart';

/// То, что синхронизации нужно от хранилища дизлайков.
///
/// Дизлайки лежат в SQLite рекомендаций, а не в prefs, поэтому они не могут
/// быть обычным [RawSyncBucket]: доступ к ним асинхронный. Интерфейс держит
/// службу обмена независимой от recs — и позволяет проверять её без базы.
abstract interface class DislikeStore {
  /// Записи, изменённые после [watermark].
  Future<List<SyncedRecord<Map<String, dynamic>>>> dirtyDislikes(int watermark);

  /// Применяет чужую запись. true — если состояние изменилось.
  Future<bool> mergeRemoteDislike(SyncedRecord<Map<String, dynamic>> incoming);
}
