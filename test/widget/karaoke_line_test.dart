import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/karaoke_line.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

const _accent = Color(0xFFB388FF);

TextStyle _styleOf(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!;

void main() {
  /// Заливка рисуется на канве: она обязана считаться по строкам разметки, а
  /// не по ширине блока, иначе перенесённая строка заливается неверно.
  Finder fillFinder() => find.descendant(
        of: find.byType(KaraokeLine),
        matching: find.byType(CustomPaint),
      );

  testWidgets('активная строка заливается, неактивная — нет', (tester) async {
    await tester.pumpWidget(_wrap(const KaraokeLine(
      text: 'строка',
      accent: _accent,
      active: true,
      progress: 0.5,
      dim: 1,
    )));
    await tester.pump();
    expect(fillFinder(), findsOneWidget);

    await tester.pumpWidget(_wrap(const KaraokeLine(
      text: 'строка',
      accent: _accent,
      active: false,
      progress: 0,
      dim: 0.5,
    )));
    await tester.pump();
    // Незачем платить за отрисовку там, где заливать нечего.
    expect(fillFinder(), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('неактивные строки бледнеют по мере удаления', (tester) async {
    await tester.pumpWidget(_wrap(const KaraokeLine(
      text: 'строка',
      accent: _accent,
      active: false,
      progress: 0,
      dim: 0.55,
    )));
    final near = _styleOf(tester).color!.a;

    await tester.pumpWidget(_wrap(const KaraokeLine(
      text: 'строка',
      accent: _accent,
      active: false,
      progress: 0,
      dim: 0.24,
    )));
    final far = _styleOf(tester).color!.a;

    expect(far, lessThan(near));
  });

  testWidgets('активная строка крупнее неактивной', (tester) async {
    // Стиль активной строки читать неоткуда — она рисуется на канве, а не
    // виджетом Text. Зато разница в кегле видна по высоте строки, а это ровно
    // то, что замечает глаз.
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 300,
      child: KaraokeLine(
        text: 'строка',
        accent: _accent,
        active: true,
        progress: 0.3,
        dim: 1,
      ),
    )));
    await tester.pump();
    final activeHeight = tester.getSize(find.byType(KaraokeLine)).height;

    await tester.pumpWidget(_wrap(const SizedBox(
      width: 300,
      child: KaraokeLine(
        text: 'строка',
        accent: _accent,
        active: false,
        progress: 0,
        dim: 0.55,
      ),
    )));
    await tester.pump();
    final idleHeight = tester.getSize(find.byType(KaraokeLine)).height;

    expect(activeHeight, greaterThan(idleHeight));
    // Неактивная не должна светиться: свечение — признак «поётся сейчас».
    expect(_styleOf(tester).shadows, isNull);
  });

  testWidgets('крайние значения доли не роняют отрисовку', (tester) async {
    for (final p in [0.0, 1.0, -0.5, 1.5]) {
      await tester.pumpWidget(_wrap(KaraokeLine(
        text: 'строка',
        accent: _accent,
        active: true,
        progress: p,
        dim: 1,
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'доля $p');
    }
  });

  testWidgets('пустой и очень длинный текст переживаются', (tester) async {
    await tester.pumpWidget(_wrap(const KaraokeLine(
      text: '♪',
      accent: _accent,
      active: true,
      progress: 0.5,
      dim: 1,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(KaraokeLine(
      text: 'очень длинная строка текста ' * 12,
      accent: _accent,
      active: true,
      progress: 0.5,
      dim: 1,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
