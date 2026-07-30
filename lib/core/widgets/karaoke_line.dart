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

  /// Ширина размытой границы заливки в долях строки. Резкий край выглядел бы
  /// как ошибка отрисовки, а не как движение.
  static const _edge = 0.08;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: active ? 25 : 19,
      height: 1.28,
      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      // Цвет для неактивных строк: чуть подкрашены акцентом, чтобы экран
      // читался как одно целое, но не спорили с активной за внимание.
      color: active
          ? Colors.white
          : Color.lerp(Colors.white, accent, 0.35)!.withValues(alpha: dim),
      shadows: active
          ? [
              // Мягкое свечение под текстом — на размытой обложке белые буквы
              // иначе теряются на светлых участках.
              Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 22),
              const Shadow(color: Colors.black54, blurRadius: 8),
            ]
          : null,
    );

    final child = Text(text, style: style);
    if (!active) return child;

    // Плавность между тиками позиции: поток отдаёт её редкими шагами, и без
    // интерполяции заливка дёргалась бы. Кривая линейная — доля спетого растёт
    // равномерно, любое ускорение выглядело бы рассинхроном.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 220),
      curve: Curves.linear,
      builder: (context, p, _) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            // Спетая часть: два тона акцента, от светлого к насыщенному.
            _lighten(accent),
            accent,
            // Ещё не спетая — белая, но приглушённая.
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.42),
          ],
          stops: [0, p, (p + _edge).clamp(0.0, 1.0), 1],
        ).createShader(rect),
        child: child,
      ),
    );
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
