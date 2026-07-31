import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/karaoke_line.dart';

/// Рисуем строку в картинку и смотрим на пиксели. Это единственный способ
/// поймать ошибку композиции слоёв: её не видно ни в дереве виджетов, ни в
/// расчётах — только на экране.
///
/// Тестовый шрифт рисует каждый символ квадратом со стороной в кегль, поэтому
/// ширина строки предсказуема: символов × fontSize.
const _accent = Color(0xFFFF0000); // чистый красный: ни с чем не спутать
const _fontSize = 25.0;
const _size = Size(400, 120);

Future<List<int>> _render(String text, double progress) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: _fontSize, color: KaraokeLine.unsung),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _size.width);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & _size);
  // Чёрная подложка: так видно, что слой действительно нарисован.
  canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.black);
  KaraokePainter(
    painter: painter,
    progress: progress,
    sung: _accent,
    sungDeep: _accent,
  ).paint(canvas, _size);

  final image = await recorder
      .endRecording()
      .toImage(_size.width.toInt(), _size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

bool _isAccent(List<int> px, int i) =>
    px[i] > 120 && px[i + 1] < 90 && px[i + 2] < 90;

/// Считает окрашенные пиксели в прямоугольнике (в координатах картинки).
int _accentIn(List<int> px, Rect area) {
  final width = _size.width.toInt();
  var count = 0;
  for (var i = 0; i < px.length; i += 4) {
    if (!_isAccent(px, i)) continue;
    final p = i ~/ 4;
    final point = Offset((p % width).toDouble(), (p ~/ width).toDouble());
    if (area.contains(point)) count++;
  }
  return count;
}

void main() {
  // 12 символов по 25 пикселей = 300 — помещается в 400 без переноса.
  const short = 'АААААААААААА';
  // 24 символа = 600: перенос на две строки по 16 и 8 символов.
  const long = 'АААААААААААААААААААААААА';

  const all = Rect.fromLTWH(0, 0, 400, 120);

  test('до пения строка не окрашена', () async {
    expect(_accentIn(await _render(short, 0), all), 0);
  });

  test('спетая целиком строка окрашена по всей длине', () async {
    final px = await _render(short, 1);
    expect(_accentIn(px, const Rect.fromLTWH(0, 0, 150, 120)), greaterThan(0));
    expect(_accentIn(px, const Rect.fromLTWH(150, 0, 150, 120)), greaterThan(0));
  });

  test('на половине окрашена только левая часть', () async {
    // Ровно тот случай, который ломался: режим наложения не стирал текст за
    // границей, и строка красилась целиком при любом прогрессе.
    final px = await _render(short, 0.5);
    final sung = _accentIn(px, const Rect.fromLTWH(0, 0, 150, 120));
    final unsung = _accentIn(px, const Rect.fromLTWH(180, 0, 220, 120));

    expect(sung, greaterThan(0));
    expect(unsung, 0, reason: 'за границей заливки цвета быть не должно');
  });

  test('перенесённая строка заливается по порядку чтения', () async {
    // Половина текста — это конец первой строки, а не начало обеих.
    final px = await _render(long, 0.5);
    const secondRow = Rect.fromLTWH(0, 30, 400, 90);

    expect(_accentIn(px, const Rect.fromLTWH(0, 0, 200, 28)), greaterThan(0),
        reason: 'первая строка должна быть окрашена');
    expect(_accentIn(px, secondRow), 0,
        reason: 'вторая строка ещё не спета');
  });
}
