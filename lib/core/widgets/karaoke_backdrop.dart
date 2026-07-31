import 'dart:math';

import 'package:flutter/material.dart';

/// Живой фон режима караоке: медленно перетекающие пятна света в палитре
/// акцента (а он в динамическом режиме вытянут из обложки).
///
/// Заменяет собой размытую обложку. Смысл не только в красоте: обложка даёт
/// случайные светлые участки, на которых белый текст теряется, и её детали
/// спорят с тем, что читаешь. Здесь же фон заведомо тёмный, а движение
/// медленное — глазу не за что зацепиться, пока он идёт по строкам.
class KaraokeBackdrop extends StatefulWidget {
  const KaraokeBackdrop({
    super.key,
    required this.accent,
    this.playing = true,
    this.beat = 0,
  });

  final Color accent;

  /// На паузе движение останавливается: фон живёт вместе с музыкой, а не сам
  /// по себе. Заодно не тратит кадры, когда экран просто открыт.
  final bool playing;

  /// Счётчик ударов: как только значение меняется, фон отзывается вспышкой.
  ///
  /// Источник намеренно не спектр аудио: настоящий бит на Android даёт только
  /// системный Visualizer, а он требует разрешения микрофона, включённой
  /// настройки и единственного владельца сессии — дёргать его из второго
  /// экрана значило бы ломать существующий визуализатор, и на вебе его нет
  /// вовсе. Зато смена строки в LRC синхронна с музыкой по построению: это
  /// разметка самой песни. Пульс идёт по ней.
  final int beat;

  @override
  State<KaraokeBackdrop> createState() => _KaraokeBackdropState();
}

class _KaraokeBackdropState extends State<KaraokeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Полный оборот — минута: за строку песни картинка успевает заметно
    // измениться, но уследить за самим движением невозможно.
    duration: const Duration(seconds: 60),
  );

  /// Вспышка на удар: резкий подъём и мягкий спад — так ведёт себя отклик на
  /// звук. Симметричная кривая читалась бы как «моргание».
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant KaraokeBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
    if (widget.beat != old.beat && widget.playing) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_c, _pulse]),
          builder: (context, _) => CustomPaint(
            painter: _BackdropPainter(
              accent: widget.accent,
              t: _c.value,
              // Между ударами — едва заметное дыхание, чтобы фон не замирал
              // на длинных строках и в проигрышах.
              pulse: _pulseValue + 0.12 * (0.5 + 0.5 * sin(_c.value * 2 * pi * 6)),
            ),
            size: Size.infinite,
          ),
        ),
      );

  /// Резкая атака (первые 12% времени) и долгий спад.
  double get _pulseValue {
    final v = _pulse.value;
    if (v <= 0 || v >= 1) return 0;
    const attack = 0.12;
    return v < attack
        ? v / attack
        : 1 - Curves.easeOutCubic.transform((v - attack) / (1 - attack));
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.accent,
    required this.t,
    this.pulse = 0,
  });

  final Color accent;

  /// Фаза 0..1.
  final double t;

  /// Сила текущего удара, 0..1 — раздувает пятна и добавляет им яркости.
  final double pulse;

  /// Пятна: доля радиуса, скорость и сдвиг фазы. Скорости намеренно не кратны
  /// друг другу — иначе картина повторялась бы каждые несколько секунд.
  static const _blobs = <({double radius, double speed, double phase, double hueShift})>[
    (radius: 0.85, speed: 1.0, phase: 0.0, hueShift: 0),
    (radius: 0.70, speed: -0.73, phase: 0.33, hueShift: 28),
    (radius: 0.55, speed: 1.41, phase: 0.66, hueShift: -34),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hsl = HSLColor.fromColor(accent);

    // Основа — почти чёрная, слегка подкрашенная акцентом. Чистый чёрный
    // выглядел бы провалом рядом с цветными пятнами.
    canvas.drawRect(
      rect,
      Paint()
        ..color = hsl
            .withLightness(0.06)
            .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
            .toColor(),
    );

    final diagonal = sqrt(size.width * size.width + size.height * size.height);

    for (final blob in _blobs) {
      final angle = 2 * pi * (t * blob.speed + blob.phase);
      // Эллиптическая траектория: по кругу пятна ходили бы синхронно и это
      // читалось бы как вращение всей картинки.
      final center = Offset(
        size.width * (0.5 + 0.34 * cos(angle)),
        size.height * (0.5 + 0.28 * sin(angle * 1.3)),
      );
      // На удар пятно раздувается и светлеет. Проценты небольшие намеренно:
      // фон под текстом, и заметная пульсация мешала бы читать.
      final radius = diagonal * blob.radius * 0.5 * (1 + 0.14 * pulse);

      final color = hsl
          .withHue((hsl.hue + blob.hueShift + 360) % 360)
          .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
          .withLightness((hsl.lightness * 0.55 + 0.12).clamp(0.0, 1.0))
          .toColor();

      canvas.drawCircle(
        center,
        radius,
        Paint()
          // Складываем свет, а не перекрываем: пятна должны просвечивать друг
          // через друга, как подсветка сквозь дым.
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.26 + 0.16 * pulse),
              color.withValues(alpha: 0.10 + 0.07 * pulse),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Затемнение к краям: тянет взгляд к центру, где идёт текст.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.t != t || old.pulse != pulse || old.accent != accent;
}
