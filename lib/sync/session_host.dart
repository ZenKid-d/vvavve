import '../domain/models/track.dart';
import 'session_snapshot.dart';

/// То, что синхронизации нужно от плеера — и ничего сверх.
///
/// Через этот интерфейс служба обмена не зависит от `RoundsAudioHandler`, а
/// значит, её можно проверять тестами без звука и без audio_service.
abstract interface class SessionHost {
  /// Текущее состояние или null, если играть нечего.
  ({List<Track> queue, int index, int positionMs})? get state;

  /// Подписка на изменения. [important] — смена трека или пауза: такое
  /// отправляем сразу, обычные тики позиции копим.
  set onChanged(void Function({required bool important})? cb);

  /// Применяет чужую сессию: ставит очередь и загружает трек на паузе.
  Future<void> adopt(SessionSnapshot snapshot);
}
