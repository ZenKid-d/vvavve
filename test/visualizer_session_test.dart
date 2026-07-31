import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/data/visualizer_session.dart';

/// Захват аудио-сессии один на приложение, и `stop()` обрывает поток всем.
/// Поэтому проверяем именно счётчик ссылок: полосы в плеере и фон караоке
/// живут одновременно, и уход с одного экрана не должен гасить другой.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('roundds/visualizer_ctrl');
  final calls = <String>[];
  var startResult = true;

  setUp(() {
    calls.clear();
    startResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'start' ? startResult : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('второй потребитель не запускает захват повторно', () async {
    final session = VisualizerSession.instance;

    expect(await session.acquire(1), isNotNull);
    expect(await session.acquire(1), isNotNull);
    expect(calls.where((c) => c == 'start').length, 1);

    session.release();
    // Один потребитель ещё держит сессию — останавливать нельзя.
    expect(calls.contains('stop'), isFalse);

    session.release();
    expect(calls.contains('stop'), isTrue);
  });

  test('неудачный запуск не оставляет висящую ссылку', () async {
    final session = VisualizerSession.instance;
    startResult = false;

    expect(await session.acquire(1), isNull);

    // Ссылка не должна была засчитаться: иначе следующий успешный захват
    // никогда бы не остановился.
    startResult = true;
    expect(await session.acquire(1), isNotNull);
    session.release();
    expect(calls.contains('stop'), isTrue);
  });

  test('лишний release не роняет счётчик ниже нуля', () async {
    final session = VisualizerSession.instance
      ..release()
      ..release();

    expect(await session.acquire(1), isNotNull);
    session.release();
    expect(calls.where((c) => c == 'stop').length, 1);
  });
}
