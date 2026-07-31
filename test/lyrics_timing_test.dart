import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/data/lyrics_service.dart';

LyricLine _l(int seconds, String text) =>
    LyricLine(Duration(milliseconds: (seconds * 1000)), text);

LyricLine _ms(int milliseconds, String text) =>
    LyricLine(Duration(milliseconds: milliseconds), text);

void main() {
  group('Темп пения', () {
    test('оценивается по строкам без пауз', () {
      // Ровный куплет: 20 символов за 2 секунды — 100 мс на символ.
      final lines = [
        for (var i = 0; i < 6; i++) _l(i * 2, 'двадцать символов ааа'),
        _l(12, ''),
      ];
      expect(estimateMsPerChar(lines), closeTo(95, 10));
    });

    test('проигрыши не замедляют оценку', () {
      // Три плотные строки и одна, после которой десятисекундный проигрыш.
      final lines = [
        _l(0, 'двадцать символов ааа'),
        _l(2, 'двадцать символов ааа'),
        _l(4, 'двадцать символов ааа'),
        _l(6, 'двадцать символов ааа'),
        _l(20, 'после проигрыша'),
      ];
      // Если бы учитывалось среднее, оценка уехала бы примерно к 200.
      expect(estimateMsPerChar(lines), lessThan(130));
    });

    test('без разметки берётся запасное значение', () {
      expect(estimateMsPerChar(const []), 85);
      expect(estimateMsPerChar([_l(0, 'одна строка')]), 85);
    });

    test('слишком длинные промежутки в выборку не попадают', () {
      // Единственная пара разделена минутой — это не темп пения.
      final lines = [_l(0, 'строка текста'), _l(60, 'вторая строка')];
      expect(estimateMsPerChar(lines), 85);
    });
  });

  group('Длительность пропевания строки', () {
    test('короткая строка перед долгой паузой допевается заранее', () {
      // 10 символов при 100 мс/символ — секунда пения, дальше проигрыш.
      final lines = [_l(0, 'десять сим'), _l(10, 'следующая строка')];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 1000,
          reason: 'заливка не должна ползти весь проигрыш');
    });

    test('строка без паузы окрашивается всю свою длину', () {
      // Оценка ровно дотягивает до следующей строки — значит паузы нет и
      // заливка обязана идти до самого конца строки, а не замирать раньше.
      final lines = [_ms(0, 'двадцать символов ааа'), _ms(2100, 'дальше')];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 2100);
    });

    test('очень короткая строка не вспыхивает мгновенно', () {
      // Три символа — 300 мс по оценке; такая вспышка не читается как заливка.
      final lines = [_ms(0, 'ааа'), _ms(5000, 'дальше')];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 600);
    });

    test('длинная строка не заезжает на следующую', () {
      // Оценка даёт 6 секунд, а до следующей строки всего две.
      final lines = [
        _l(0, 'очень длинная строка на шестьдесят символов ааааааааааааааа'),
        _l(2, 'следующая'),
      ];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 2000);
    });

    test('обычная строка поётся по оценке темпа', () {
      final lines = [_ms(0, 'двадцать символов ааа'), _ms(4000, 'дальше')];
      // 21 символ × 100 мс = 2.1 с; промежуток 4 с, нижний предел 1.4 с.
      expect(singingSpan(lines, 0, 100).inMilliseconds, closeTo(2100, 50));
    });

    test('пустая строка ждёт следующую целиком', () {
      final lines = [_l(0, ''), _l(3, 'после паузы')];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 3000);
    });

    test('последняя строка оценивается по длине текста', () {
      final lines = [_l(0, 'десять сим')];
      expect(singingSpan(lines, 0, 100).inMilliseconds, 1000);
    });

    test('выход за границы списка не роняет расчёт', () {
      final lines = [_l(0, 'строка')];
      expect(singingSpan(lines, -1, 100), Duration.zero);
      expect(singingSpan(lines, 5, 100), Duration.zero);
      expect(singingSpan(const [], 0, 100), Duration.zero);
    });
  });
}
