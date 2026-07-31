import 'package:flutter/material.dart';

/// Строка синхронного текста с заливкой «в такт».
///
/// Активная строка не просто подсвечивается целиком: цвет затекает по ней
/// слева направо ровно с той скоростью, с какой строку поют. Это не украшение
/// — по положению границы видно, где именно ты находишься внутри строки, чего
/// обычная подсветка не показывает.
///
/// Цвета берутся от акцента, а он в динамическом режиме вытянут из обложки:
/// текст оказывается в палитре того, что играет.
class KaraokeLine extends StatelessWidget {
  const KaraokeLine({
    super.key,
    required this.text,
    required this.accent,
    required this.active,
    required this.progress,
    required this.dim,
  });

  final String text;

  /// Акцент текущего трека (в динамическом режиме — из обложки).
  final Color accent;

  /// Поётся ли эта строка прямо сейчас.
  final bool active;

  /// Насколько строка спета, 0..1. Имеет смысл только у активной.
  final double progress;

  /// Прозрачность неактивной строки — чем дальше от текущей, тем бледнее.
  final double dim;

  /// Ширина размытой границы заливки в логических пикселях. Резкий край
  /// выглядел бы как ошибка отрисовки, а не как движение.
  static const _edge = 26.0;

  /// Цвет ещё не спетой части активной строки.
  ///
  /// Приглушённый, а не белый: строка должна сначала быть тусклой и
  /// окрашиваться по мере пения. Сплошной белый снизу делает заливку почти
  /// незаметной — строка выглядит вспыхнувшей целиком, сколько бы ни длилось
  /// само окрашивание.
  static const unsung = Color(0x6BFFFFFF); // белый, 42%

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final style = base.copyWith(
      fontSize: active ? 25 : 19,
      height: 1.28,
      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      // Активная строка рисуется в два слоя: снизу — ещё не спетая часть,
      // поверх неё заливка. Неактивные чуть подкрашены акцентом, чтобы экран
      // читался как одно целое, но не спорили с активной за внимание.
      color: active
          ? unsung
          : Color.lerp(Colors.white, accent, 0.35)!.withValues(alpha: dim),
      shadows: active
          ? [
              // Мягкое свечение под текстом — на подвижном фоне белые буквы
              // иначе теряются на светлых участках.
              Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 22),
              const Shadow(color: Colors.black54, blurRadius: 8),
            ]
          : null,
    );

    if (!active) return Text(text, style: style);

    // Плавность между тиками позиции: поток отдаёт её редкими шагами, и без
    // интерполяции заливка дёргалась бы. Кривая линейная — доля спетого растёт
    // равномерно, любое ускорение выглядело бы рассинхроном.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 220),
      curve: Curves.linear,
      builder: (context, p, _) => LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth);

          return CustomPaint(
            size: Size(constraints.maxWidth, painter.height),
            painter: KaraokePainter(
              painter: painter,
              progress: p,
              sung: _lighten(accent),
              sungDeep: accent,
            ),
          );
        },
      ),
    );
  }

  /// Сколько пикселей каждой визуальной строки уже спето.
  ///
  /// Доля раскладывается по строкам последовательно, как их читают: сначала
  /// добивается первая, потом начинается вторая. Если считать долю от ширины
  /// блока (как делает градиент во всю рамку), у перенесённой строки начало
  /// второго ряда закрасится раньше конца первого — ровно этот баг здесь и
  /// исключён.
  @visibleForTesting
  static List<double> sungWidths(List<LineMetrics> lines, double progress) {
    final total = lines.fold<double>(0, (sum, l) => sum + l.width);
    if (total <= 0) return List.filled(lines.length, 0);
    var remaining = total * progress.clamp(0.0, 1.0);
    return [
      for (final line in lines)
        if (remaining <= 0)
          0.0
        else ...[
          () {
            final w = remaining >= line.width ? line.width : remaining;
            remaining -= w;
            return w;
          }()
        ]
    ];
  }

  /// Осветлённый вариант акцента для градиента заливки.
  ///
  /// Через HSL, а не подмешиванием белого: у насыщенного акцента примесь белого
  /// «вымывает» цвет в пастель, а подъём светлоты сохраняет оттенок.
  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Рисует строку дважды: целиком «неспетой», а поверх — спетую часть, обрезанную
/// по длине пропетого текста.
///
/// Ключевой момент — обрезка идёт по **строкам разметки**, а не по ширине всего
/// блока. Длинная строка переносится на две, и градиент во всю ширину заливал бы
/// обе одинаково: начало второй строки закрашивалось раньше, чем конец первой.
/// Поэтому доля раскладывается по строкам последовательно, как их и читают.
@visibleForTesting
class KaraokePainter extends CustomPainter {
  KaraokePainter({
    required this.painter,
    required this.progress,
    required this.sung,
    required this.sungDeep,
  });

  final TextPainter painter;
  final double progress;
  final Color sung;
  final Color sungDeep;

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(canvas, Offset.zero);
    if (progress <= 0) return;

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) return;

    // Доля считается от суммарной длины всех визуальных строк: только так
    // «половина спета» означает середину текста, а не середину каждой строки.
    final widths = KaraokeLine.sungWidths(lines, progress);

    // Спетые куски строк. Отсечение — именно отсечением, а не режимом
    // наложения: режим действует только на пиксели, которые накрыла сама
    // фигура, поэтому «стереть всё за прямоугольником» им нельзя — текст за
    // границей оставался бы нарисованным, и строка красилась бы целиком.
    final sungArea = Path();
    final fades = <Rect>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final width = widths[i];
      if (width <= 0) break;
      final top = line.baseline - line.ascent;
      sungArea.addRect(Rect.fromLTWH(line.left, top, width, line.height));

      // Хвост границы гасим градиентом — резкий край читался бы как артефакт.
      final from = line.left + width - KaraokeLine._edge;
      final to = line.left + width;
      if (to > from) fades.add(Rect.fromLTRB(from, top, to, top + line.height));
    }

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.save();
    canvas.clipPath(sungArea);
    _sungPainter(size).paint(canvas, Offset.zero);
    canvas.restore();

    // Растушёвка переднего края: здесь режим наложения уместен — он работает
    // ровно в пределах узкой полосы, которую и надо сгладить.
    for (final fade in fades) {
      canvas.drawRect(
        fade,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Colors.white.withValues(alpha: 0)],
          ).createShader(fade),
      );
    }
    canvas.restore();
  }

  /// Та же разметка, но цветом заливки: переносы обязаны совпасть с исходными,
  /// иначе спетая часть съедет относительно текста под ней.
  TextPainter _sungPainter(Size size) {
    final span = painter.text as TextSpan;
    return TextPainter(
      text: TextSpan(
        text: span.text,
        // color и foreground одновременно задать нельзя — цвет здесь целиком
        // задаётся кистью градиента.
        style: TextStyle(
          fontSize: span.style?.fontSize,
          fontWeight: span.style?.fontWeight,
          fontFamily: span.style?.fontFamily,
          fontFamilyFallback: span.style?.fontFamilyFallback,
          letterSpacing: span.style?.letterSpacing,
          wordSpacing: span.style?.wordSpacing,
          height: span.style?.height,
          // Тень уже нарисована нижним слоем; вторая по тем же буквам сделала бы
          // свечение вдвое плотнее.
          foreground: Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [sung, sungDeep],
            ).createShader(Offset.zero & size),
        ),
      ),
      textDirection: painter.textDirection ?? TextDirection.ltr,
    )..layout(maxWidth: size.width);
  }

  @override
  bool shouldRepaint(KaraokePainter old) =>
      old.progress != progress ||
      old.sung != sung ||
      old.sungDeep != sungDeep ||
      old.painter.text != painter.text;
}
