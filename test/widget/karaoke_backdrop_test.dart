import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/karaoke_backdrop.dart';

const _accent = Color(0xFFB388FF);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('фон рисуется и переживает смену акцента', (tester) async {
    await tester.pumpWidget(_wrap(const KaraokeBackdrop(accent: _accent)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(KaraokeBackdrop), findsOneWidget);

    await tester.pumpWidget(
        _wrap(const KaraokeBackdrop(accent: Color(0xFF3FBF7F))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('на паузе движение останавливается', (tester) async {
    await tester.pumpWidget(
        _wrap(const KaraokeBackdrop(accent: _accent, playing: false)));
    // Если бы контроллер продолжал крутиться, pumpAndSettle не завершился бы.
    await tester.pumpAndSettle();
    expect(find.byType(KaraokeBackdrop), findsOneWidget);
  });

  testWidgets('смена строки даёт вспышку и затухает', (tester) async {
    await tester.pumpWidget(
        _wrap(const KaraokeBackdrop(accent: _accent, beat: 1)));
    await tester.pump();

    await tester.pumpWidget(
        _wrap(const KaraokeBackdrop(accent: _accent, beat: 2)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Вспышка конечна: после неё анимация пульса завершается сама.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('подписка на спектр закрывается вместе с виджетом',
      (tester) async {
    final controller = StreamController<List<double>>.broadcast();

    await tester.pumpWidget(_wrap(KaraokeBackdrop(
      accent: _accent,
      spectrum: controller.stream,
    )));
    await tester.pump();
    expect(controller.hasListener, isTrue);

    controller.add(List.filled(32, 0.8));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(const SizedBox()));
    await tester.pump();
    // Незакрытая подписка держала бы виджет и капала событиями в никуда.
    expect(controller.hasListener, isFalse);
    await controller.close();
  });

  testWidgets('пустой кадр спектра не роняет отрисовку', (tester) async {
    final controller = StreamController<List<double>>.broadcast();
    await tester.pumpWidget(_wrap(KaraokeBackdrop(
      accent: _accent,
      spectrum: controller.stream,
    )));
    await tester.pump();

    controller.add(const []);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await controller.close();
  });
}
