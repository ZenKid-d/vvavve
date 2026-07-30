import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_service.dart' show SyncState;
import '../providers.dart' show themeSettingsProvider;
import '../theme/accent_provider.dart';
import '../theme/app_colors.dart';

/// Строка статуса синхронизации с переливом в цветах акцента.
///
/// Акцент в динамическом режиме вычисляется из обложки текущего трека, поэтому
/// перелив «подхватывает» цвет того, что играет. Смысл не в украшении: пока
/// идёт обмен, по строке бежит волна, и остановка волны сама по себе означает,
/// что всё синхронизировано — это заметно боковым зрением, в отличие от смены
/// текста.
class SyncStatusText extends ConsumerStatefulWidget {
  const SyncStatusText({
    super.key,
    required this.text,
    required this.state,
    this.fontSize = 11,
  });

  final String text;
  final SyncState state;
  final double fontSize;

  @override
  ConsumerState<SyncStatusText> createState() => _SyncStatusTextState();
}

class _SyncStatusTextState extends ConsumerState<SyncStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant SyncStatusText old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _apply();
  }

  void _apply() {
    // «Минимум анимаций» должен останавливать не только отрисовку, но и сам
    // контроллер: иначе он бесконечно запрашивает кадры ради перелива, которого
    // никто не видит, — впустую тратит батарею и не даёт тестам устояться.
    if (!ref.read(themeSettingsProvider).spin) {
      _c.stop();
      _c.value = 0;
      return;
    }
    switch (widget.state) {
      case SyncState.syncing:
        // Обмен идёт — волна бежит по кругу.
        if (!_c.isAnimating) _c.repeat();
      case SyncState.idle:
        // Закончили: один проход волны как «готово» и остановка.
        _c.stop();
        _c.forward(from: 0);
      case SyncState.error:
      case SyncState.off:
        _c.stop();
        _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Три оттенка вокруг акцента: перелив должен читаться как игра одного цвета,
  /// а не как радуга поперёк интерфейса.
  List<Color> _palette(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    final base = hsl.withSaturation(hsl.saturation.clamp(0.45, 1.0));
    return [
      base.withHue((base.hue - 28 + 360) % 360).withLightness(0.62).toColor(),
      base.withLightness(0.78).toColor(),
      base.withHue((base.hue + 28) % 360).withLightness(0.62).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(effectiveAccentProvider);
    final reduceMotion = !ref.watch(themeSettingsProvider).spin;

    // Ошибка не должна выглядеть нарядно: там нужен нейтральный цвет, а не
    // акцент, иначе «облако недоступно» читается как что-то хорошее.
    final muted = widget.state == SyncState.error
        ? AppColors.white45
        : Color.lerp(AppColors.white45, accent, 0.55)!;

    final style = TextStyle(fontSize: widget.fontSize, color: muted);

    if (reduceMotion ||
        widget.state == SyncState.error ||
        widget.state == SyncState.off) {
      // Настройку могли переключить уже после запуска волны.
      if (_c.isAnimating) _c.stop();
      return Text(widget.text, style: style);
    }

    final colors = _palette(accent);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Волна уходит за край и возвращается: от -1 до 1 по ширине строки.
        final shift = _c.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [muted, ...colors, muted],
            stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
            transform: _SweepTransform(shift),
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(widget.text, style: style),
    );
  }
}

/// Сдвигает градиент вдоль строки — так получается бегущая волна, а не
/// мерцание всей строки целиком.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.shift);

  /// -1 — волна слева за краем, 1 — справа за краем.
  final double shift;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * shift, 0, 0);
}
