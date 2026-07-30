import '../domain/models/track.dart';
import '../sync/session_host.dart';
import '../sync/session_snapshot.dart';
import 'audio_handler.dart';

/// Переходник между плеером и синхронизацией сессии.
///
/// Существует ради развязки: `lib/sync` не должен знать про audio_service, а
/// плеер — про облако.
class HandlerSessionHost implements SessionHost {
  HandlerSessionHost(this._handler);

  final RoundsAudioHandler _handler;

  @override
  ({List<Track> queue, int index, int positionMs})? get state =>
      _handler.sessionState;

  @override
  set onChanged(void Function({required bool important})? cb) =>
      _handler.onSessionSaved = cb;

  @override
  Future<void> adopt(SessionSnapshot snapshot) => _handler.restoreSession(
        snapshot.queue,
        snapshot.index,
        snapshot.position,
        // Пользователь согласился перенести — значит, заменяем то, что стоит
        // в очереди сейчас. Загрузка всё равно происходит на паузе: браузер
        // не даст заиграть без нажатия, да и внезапный звук был бы грубостью.
        force: true,
      );
}
