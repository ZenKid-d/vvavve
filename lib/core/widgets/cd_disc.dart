import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/seed_palette.dart';

/// «Голый» компакт-диск: непрозрачный зеркальный пластик с переливами, дорожки
/// данных, кольцо-хаб и печать с именем артиста (по верхней дуге) и названием
/// трека (по нижней). Обложка на диск НЕ печатается — как у болванки без
/// полиграфии.
///
/// Цвет переливов ведётся от [accent]: в динамическом режиме темы он взят из
/// обложки, так что диск попадает в палитру текущего трека. Угол блика — из
/// [stableSeedHash] строки «артист — название», поэтому у одной и той же песни
/// он один и тот же и после перезапуска приложения.
class CdDisc extends StatefulWidget {
  const CdDisc({
    super.key,
    required this.isPlaying,
    required this.accent,
    required this.artist,
    required this.title,
    this.size = 240,
  });

  final bool isPlaying;
  final Color accent;
  final String artist;
  final String title;
  final double size;

  @override
  State<CdDisc> createState() => _CdDiscState();
}

class _CdDiscState extends State<CdDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant CdDisc old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.isPlaying && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    // Шрифт берём из темы, чтобы печать на диске не выпадала из типографики
    // приложения (Poppins или системный — по настройке).
    final base = DefaultTextStyle.of(context).style;
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accent
                  .withValues(alpha: widget.isPlaying ? 0.45 : 0.22),
              blurRadius: 46,
              spreadRadius: 2,
            ),
          ],
        ),
        child: RotationTransition(
          turns: _c,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CdPainter(
                accent: widget.accent,
                hash: stableSeedHash('${widget.artist} — ${widget.title}'),
                artist: widget.artist,
                title: widget.title,
                baseStyle: base,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Рисует диск целиком: зеркальный пластик, переливы, дорожки, надписи,
/// прозрачный хаб и центральное отверстие. Радиусы — в долях радиуса диска.
class _CdPainter extends CustomPainter {
  _CdPainter({
    required this.accent,
    required this.hash,
    required this.artist,
    required this.title,
    required this.baseStyle,
  });

  final Color accent;
  final int hash;
  final String artist;
  final String title;
  final TextStyle baseStyle;

  /// Граница печатной зоны — внутри неё у настоящего диска прозрачный пластик.
  static const _printEdge = 0.36;
  static const _hubInner = 0.20;
  static const _hubOuter = 0.33;
  static const _hole = 0.13;
  static const _artistRadius = 0.80;
  static const _titleRadius = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.shortestSide;
    final r = d / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final disc = Rect.fromCircle(center: center, radius: r);

    _metal(canvas, center, r, disc);
    _sheen(canvas, center, r, disc);
    _tracks(canvas, center, r);
    _print(canvas, center, r, d);
    _hub(canvas, center, r);
  }

  /// Зеркальный пластик: холодное серебро, чуть темнее к краю, плюс мягкая
  /// диагональная засветка — на неё дальше ложится радуга.
  void _metal(Canvas canvas, Offset center, double r, Rect disc) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFF2F5F7),
            Color(0xFFDCE2E7),
            Color(0xFFAFB8C0),
            Color(0xFF8C959D),
          ],
          stops: [0.0, 0.45, 0.86, 1.0],
        ).createShader(disc),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(disc),
    );
  }

  /// Перелив + блик. Цвет перелива водим вокруг оттенка [accent] (а он в
  /// динамическом режиме взят из обложки), поэтому диск попадает в палитру
  /// текущего трека, а не светится случайной радугой. Угол блика зависит от
  /// хеша трека — это разводит визуально даже треки с похожей обложкой.
  void _sheen(Canvas canvas, Offset center, double r, Rect disc) {
    final hsl = HSLColor.fromColor(accent);
    // Насыщенность поднимаем: у приглушённого акцента перелив иначе выродился
    // бы в серое пятно.
    final sat = max(0.55, hsl.saturation);
    // Два лепестка по кругу: оттенок ходит ±_hueSpan вокруг акцента, как у
    // настоящего CD, где радуга повторяется дважды.
    const steps = 24;
    const hueSpan = 55.0;
    final ring = <Color>[
      for (var i = 0; i < steps; i++)
        HSLColor.fromAHSL(
          1,
          (hsl.hue + hueSpan * sin(4 * pi * i / steps) + 360) % 360,
          sat,
          0.55 + 0.12 * cos(4 * pi * i / steps),
        ).toColor().withValues(alpha: 0.34),
    ];
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..blendMode = BlendMode.overlay
        ..shader = SweepGradient(
          colors: [...ring, ring.first],
        ).createShader(disc),
    );

    // Узкий «отблеск» — два световых сектора на противоположных сторонах.
    final specular = ((hash >> 17) % 360) * pi / 180;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.06, 0.16, 0.48, 0.54, 0.64],
          transform: GradientRotation(specular),
        ).createShader(disc),
    );
  }

  /// Концентрические дорожки данных и границы печатной зоны — по ним диск
  /// читается как CD, а не как винил.
  void _tracks(Canvas canvas, Offset center, double r) {
    final track = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final t = _printEdge + (0.99 - _printEdge) * i / 7;
      track
        ..color = Colors.white.withValues(alpha: i.isEven ? 0.30 : 0.16)
        ..strokeWidth = i.isEven ? 1.0 : 0.6;
      canvas.drawCircle(center, r * t, track);
    }
    // Внутренняя кромка данных подсвечена акцентом — связывает диск с темой.
    canvas.drawCircle(
      center,
      r * _printEdge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.45),
    );
    // Внешняя кромка.
    canvas.drawCircle(
      center,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  /// Печать: артист по верхней дуге, название — по нижней (буквы «макушками»
  /// к центру, как на настоящей круговой печати — читается без поворота).
  /// Буквы тёмные: на серебре белое не читалось бы.
  void _print(Canvas canvas, Offset center, double r, double d) {
    final halo = <Shadow>[
      Shadow(color: Colors.white.withValues(alpha: 0.55), blurRadius: 3),
    ];
    final artistStyle = baseStyle.copyWith(
      color: const Color(0xFF14181C),
      fontSize: d * 0.052,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      height: 1.0,
      shadows: halo,
    );
    final titleStyle = baseStyle.copyWith(
      color: const Color(0xFF14181C).withValues(alpha: 0.88),
      fontSize: d * 0.046,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      height: 1.0,
      shadows: halo,
    );

    _arcText(canvas, center, artist.toUpperCase(), artistStyle,
        radius: r * _artistRadius, maxSweep: 3.6, bottom: false);
    _arcText(canvas, center, title, titleStyle,
        radius: r * _titleRadius, maxSweep: 3.4, bottom: true);
  }

  /// Прозрачное кольцо-хаб, зеркальный поясок и центральное отверстие — это то,
  /// по чему диск сразу читается как CD, а не как винил.
  void _hub(Canvas canvas, Offset center, double r) {
    final hubRect = Rect.fromCircle(center: center, radius: r * _hubOuter);
    // Зона зажима: прозрачный пластик — мутноватое стекло, светлее пластика.
    canvas.drawCircle(center, r * _hubOuter,
        Paint()..color = Colors.white.withValues(alpha: 0.38));
    // Стеклянный блик на пластике.
    canvas.drawCircle(
      center,
      r * _hubOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.30),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(hubRect),
    );
    // Кольца, ограничивающие прозрачную зону, и кольцо-«ступенька» зажима.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.28);
    canvas.drawCircle(center, r * _hubOuter, edge);
    canvas.drawCircle(center, r * _hubInner, edge);
    canvas.drawCircle(
      center,
      r * 0.265,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.14),
    );

    // Отверстие.
    canvas.drawCircle(center, r * _hole, Paint()..color = Colors.black);
    canvas.drawCircle(
      center,
      r * _hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  /// Рисует строку по дуге радиуса [radius], центрируя её сверху ([bottom] ==
  /// false) или снизу диска. Строка, не влезающая в [maxSweep] радиан, режется
  /// с многоточием.
  void _arcText(
    Canvas canvas,
    Offset center,
    String text,
    TextStyle style, {
    required double radius,
    required double maxSweep,
    required bool bottom,
  }) {
    if (text.trim().isEmpty || radius <= 0) return;
    final glyphs = _layout(text.trim(), style, maxSweep * radius);
    if (glyphs.isEmpty) return;

    var total = 0.0;
    for (final g in glyphs) {
      total += g.width;
    }
    final sweep = total / radius;
    // Верхняя дуга идёт по часовой от -sweep/2, нижняя — против часовой от
    // pi + sweep/2: в обоих случаях текст читается слева направо.
    var angle = bottom ? pi + sweep / 2 : -sweep / 2;

    for (final g in glyphs) {
      final step = g.width / radius;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(bottom ? angle - step / 2 : angle + step / 2);
      canvas.translate(0, -radius);
      if (bottom) canvas.rotate(pi);
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      angle += bottom ? -step : step;
    }
  }

  /// Раскладывает строку посимвольно, обрезая по [maxWidth] с многоточием.
  List<TextPainter> _layout(String text, TextStyle style, double maxWidth) {
    final out = <TextPainter>[];
    var w = 0.0;
    for (final g in _glyphs(text)) {
      final tp = _painter(g, style);
      if (w + tp.width > maxWidth) {
        final dots = _painter('…', style);
        while (out.isNotEmpty && w + dots.width > maxWidth) {
          w -= out.removeLast().width;
        }
        if (w + dots.width <= maxWidth) out.add(dots);
        break;
      }
      out.add(tp);
      w += tp.width;
    }
    return out;
  }

  TextPainter _painter(String s, TextStyle style) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Разбивает строку на символы, не разрывая суррогатные пары (эмодзи).
  List<String> _glyphs(String s) {
    final out = <String>[];
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (u >= 0xD800 && u <= 0xDBFF && i + 1 < s.length) {
        out.add(s.substring(i, i + 2));
        i++;
      } else {
        out.add(s[i]);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_CdPainter old) =>
      old.accent != accent ||
      old.hash != hash ||
      old.artist != artist ||
      old.title != title ||
      old.baseStyle != baseStyle;
}
