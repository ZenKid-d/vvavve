import 'synced_record.dart';

/// Одна запись «на проводе»: то же, что [SyncedRecord], плюс серверное время.
class RemoteDoc {
  const RemoteDoc({required this.record, required this.serverAt});

  final SyncedRecord<Map<String, dynamic>> record;

  /// Время сервера, по которому ведётся курсор дочитывания. Для разрешения
  /// конфликтов оно не годится: локально его ещё нет в момент записи, и часы
  /// у него другие — сравнивать надо `updatedAt`.
  final int serverAt;
}

/// Куда и как ездят записи.
///
/// Отдельный интерфейс, а не прямые вызовы Firestore по коду: сервисы Google
/// в России периодически недоступны, и запасной путь — те же данные через
/// собственный прокси-сервер. С этим слоем такая замена стоит одного класса,
/// без переписывания логики слияния.
abstract interface class SyncTransport {
  /// Изменения в коллекции, начиная с [since] (серверное время). Поток живой:
  /// сначала приходит накопленное, затем — правки по мере появления.
  Stream<List<RemoteDoc>> watch(String collection, {required int since});

  /// Отправляет записи. Должно быть идемпотентно: повторная отправка той же
  /// записи не меняет результат (слияние на другой стороне это переживает).
  Future<void> push(String collection, List<SyncedRecord<Map<String, dynamic>>> records);

  Future<void> dispose();
}
