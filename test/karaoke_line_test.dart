import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/karaoke_line.dart';

/// Строка разметки нужной ширины. Остальные поля на расчёт не влияют.
LineMetrics _line(double width, int number) => LineMetrics(
      hardBreak: false,
      ascent: 20,
      descent: 6,
      unscaledAscent: 20,
      height: 26,
      width: width,
      left: 0,
      baseline: 20 + 26.0 * number,
      lineNumber: number,
    );

void main() {
  group('Заливка караоке по перенесённым строкам', () {
    test('короткая строка заливается пропорционально', () {
      final w = KaraokeLine.sungWidths([_line(200, 0)], 0.25);
      expect(w, [50]);
    });

    test('половина длинной строки — это конец первого ряда, а не начало обоих',
        () {
      // Ровно тот баг, который был виден на экране: градиент во всю рамку
      // заливал каждый ряд на одну и ту же долю, и начало второго ряда
      // подсвечивалось раньше, чем допевался первый.
      final w = KaraokeLine.sungWidths([_line(300, 0), _line(300, 1)], 0.5);
      expect(w, [300, 0]);
    });

    test('заливка переходит на второй ряд только после первого', () {
      final w = KaraokeLine.sungWidths([_line(300, 0), _line(100, 1)], 0.875);
      expect(w[0], 300);
      expect(w[1], closeTo(50, 0.001));
    });

    test('ряды разной длины: доля считается от суммы, а не от числа рядов', () {
      // Первый ряд втрое длиннее второго. На 25% спета четверть общего текста,
      // то есть треть первого ряда — второй ещё не начат.
      final w = KaraokeLine.sungWidths([_line(300, 0), _line(100, 1)], 0.25);
      expect(w[0], closeTo(100, 0.001));
      expect(w[1], 0);
    });

    test('края: ничего и всё', () {
      final lines = [_line(300, 0), _line(120, 1)];
      expect(KaraokeLine.sungWidths(lines, 0), [0, 0]);
      expect(KaraokeLine.sungWidths(lines, 1), [300, 120]);
      // За границы диапазона выходить нельзя даже при кривом прогрессе.
      expect(KaraokeLine.sungWidths(lines, 1.5), [300, 120]);
      expect(KaraokeLine.sungWidths(lines, -1), [0, 0]);
    });

    test('пустая разметка не роняет расчёт', () {
      expect(KaraokeLine.sungWidths(const [], 0.5), isEmpty);
      expect(KaraokeLine.sungWidths([_line(0, 0)], 0.5), [0]);
    });

    test('три ряда заливаются по очереди', () {
      final lines = [_line(100, 0), _line(100, 1), _line(100, 2)];
      final w = KaraokeLine.sungWidths(lines, 2 / 3);
      expect(w[0], 100);
      expect(w[1], closeTo(100, 0.001));
      expect(w[2], 0);
    });
  });
}
