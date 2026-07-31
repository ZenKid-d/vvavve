import 'visualizer_channel.dart';

/// Общий владелец нативного Visualizer.
///
/// Захват аудио-сессии один на приложение: кто угодно может вызвать `stop()`, и
/// он оборвёт поток всем сразу. Пока потребитель был один (полосы в плеере),
/// это сходило с рук; с появлением второго (фон караоке) нужен счётчик ссылок —
/// иначе закрытие одного экрана гасит спектр на другом.
class VisualizerSession {
  VisualizerSession._();
  static final VisualizerSession instance = VisualizerSession._();

  int _refs = 0;
  bool _running = false;
  Future<bool>? _starting;

  /// Захватывает сессию и отдаёт поток полос спектра. null — не удалось
  /// (нет нативной поддержки, отказано в доступе, сессия недоступна).
  ///
  /// Разрешение микрофона здесь не запрашивается: спрашивать его должен тот,
  /// кто показывает пользователю, зачем оно нужно.
  Future<Stream<List<double>>?> acquire(int sessionId) async {
    _refs++;
    if (_running) return VisualizerChannel.instance.bands;

    // Второй вызов, пока идёт запуск, ждёт того же результата, а не запускает
    // захват повторно.
    _starting ??= VisualizerChannel.instance.start(sessionId);
    final ok = await _starting!;
    _starting = null;

    if (!ok) {
      _refs--;
      return null;
    }
    _running = true;
    return VisualizerChannel.instance.bands;
  }

  /// Отпускает сессию. Захват останавливается, когда её отпустили все.
  void release() {
    if (_refs > 0) _refs--;
    if (_refs == 0 && _running) {
      _running = false;
      VisualizerChannel.instance.stop();
    }
  }
}
