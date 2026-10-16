import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../tokens/design_tokens.dart';

export '../widgets/blocks.dart'
    show EmptyState, ErrorBlock, LoadingBlock, SectionHeader, SkinCanvas;

/// Строка меню iPod: монохромная, почти без скруглений.
///
/// Отличие от iOS-строки не в размере, а в «обратном» принципе: iOS заливает
/// строку поверхностью и показывает подпись, iPod рисует саму строку-разделитель
/// и оставляет фон видным — так корпус остаётся цельным.
class IpodListRow extends StatelessWidget {
  const IpodListRow({
    super.key,
    required this.tokens,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final DesignTokens tokens;
  final AppIconData? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Выбранный пункт — инвертированный блок (классический iPod).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final fg = selected ? tokens.accentOn : tokens.textPrimary;
    final bg = selected ? tokens.accent : null;
    return Material(
      color: bg ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border(
              bottom: BorderSide(color: tokens.separator, width: 1),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space8,
            vertical: tokens.space8,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                AppIcon(leading!, size: 18, color: fg),
                SizedBox(width: tokens.space8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarqueeTitle(
                      tokens: tokens,
                      text: title,
                      style: tokens.body.copyWith(color: fg),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.micro.copyWith(
                          color: selected
                              ? tokens.accentOn.withValues(
                                  alpha: tokens.accentOn.a * 0.65,
                                )
                              : tokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.space8),
                trailing!,
              ] else
                AppIcon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: fg.withValues(alpha: fg.a * 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заголовок, который едет по кругу, если не помещается.
///
/// Сделано на [SingleChildScrollView] + [AnimationController], а не на
/// [CustomPaint]/layout-дельту: прокрутка не пересчитывает раскладку, не
/// трогает кеш текста и умеет остановиться одним жестом. Собственный
/// AnimationController нужен только чтобы гнать позицию прокрутки, потому что
/// «бесконечный» цикл всё равно приходится периодически перезапускать.
class MarqueeTitle extends StatefulWidget {
  const MarqueeTitle({
    super.key,
    required this.tokens,
    required this.text,
    this.style,
  });

  final DesignTokens tokens;
  final String text;
  final TextStyle? style;

  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle>
    with SingleTickerProviderStateMixin {
  /// Контроллер создаётся в initState, а не «лениво» в поле: в dispose() поле
  /// иначе создавалось бы впервые — уже после того, как элемент отключён от
  /// дерева, и Flutter падал бы на lookup предка тикера.
  late final AnimationController _c;

  final ScrollController _scroll = ScrollController();

  /// Нужна ли прокрутка вообще. Определяем по maxScrollExtent: если текст
  /// влезает, анимация даже не запускается и не жжёт кадры.
  bool _overflowing = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addListener(_tick);
    // Первый кадр нужен, чтобы ScrollController узнал свои размеры.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(MarqueeTitle old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    final overflows = _scroll.hasClients && _scroll.position.maxScrollExtent > 1;
    if (overflows == _overflowing) return;
    setState(() => _overflowing = overflows);
    if (overflows) {
      _c.repeat();
    } else {
      _c.stop();
      _c.reset();
    }
  }

  void _tick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 1) {
      // Текст ужался — возвращаемся в начало и останавливаемся.
      _scroll.jumpTo(0);
      _c.stop();
      return;
    }
    // Пауза в начале и в конце: текст должен успевать прочитаться, а не
    // мельтешить без остановки.
    final phase = _c.value;
    final t = ((phase - 0.12) / 0.76).clamp(0.0, 1.0);
    _scroll.jumpTo(Curves.easeInOut.transform(t) * max);
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      // Прокрутка нужна только для анимации заголовка, водить пальцем по
      // строке списка нечего — поэтому физика жёстко выключена.
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: widget.style ?? widget.tokens.headline,
      ),
    );
  }
}

/// Шапка меню iPod: заголовок по центру, шевроны и настройки по краям.
class IpodMenuBar extends StatelessWidget {
  const IpodMenuBar({
    super.key,
    required this.tokens,
    required this.title,
    this.onBack,
    this.onSettings,
    this.height = 44,
  });

  final DesignTokens tokens;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.separator)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: AppIcon(AppIcons.back,
                        size: 20, color: tokens.textSecondary),
                  ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.headline.copyWith(color: tokens.textPrimary),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: onSettings == null
                ? null
                : IconButton(
                    onPressed: onSettings,
                    icon: AppIcon(AppIcons.gear,
                        size: 20, color: tokens.textSecondary),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Графитовый фон iPod.
///
/// Текстура нарисована кодом, а не загружена картинкой: это избавляет от
/// зависимости от pubspec-assets, не тянет файл в сборку и позволяет тонировать
/// фон под любой размер экрана. Штриховка и зерно — два `drawPoints`/`drawPath`
/// за кадр, то есть один вызов растеризатора; на 60 fps это незаметно.
class GraphiteBackground extends StatelessWidget {
  const GraphiteBackground({
    super.key,
    required this.child,
    this.base = const Color(0xFF0E0E10),
    this.grainOpacity = 0.05,
    this.showGloss = true,
  });

  final Widget child;
  final Color base;
  final double grainOpacity;
  final bool showGloss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.white, 0.05)!,
            base,
            Color.lerp(base, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: CustomPaint(
        painter: _GraphitePainter(
          base: base,
          grainOpacity: grainOpacity,
          showGloss: showGloss,
        ),
        child: child,
      ),
    );
  }
}

class _GraphitePainter extends CustomPainter {
  const _GraphitePainter({
    required this.base,
    required this.grainOpacity,
    required this.showGloss,
  });

  final Color base;
  final double grainOpacity;
  final bool showGloss;

  /// Зерно генерируется один раз в нормализованном виде (0..1) и потом просто
  /// масштабируется под размер экрана — иначе каждый кадр нашлось бы заново
  /// рисовать случайные точки, а картинка «пылила» бы при прокрутке.
  static final List<Offset> _grain = _makeGrain();

  static List<Offset> _makeGrain() {
    final r = math.Random(0x6976); // «iPod» — зерно должно быть одинаковым.
    return List.generate(1400, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Едва заметная горизонтальная штриховка — «протяжка» листа графита.
    final hatch = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    final path = Path();
    for (var y = 0.0; y < h; y += 3) {
      path
        ..moveTo(0, y)
        ..lineTo(w, y);
    }
    canvas.drawPath(path, hatch);

    // Зерно: один drawPoints на все точки — дёшево и достаточно.
    final points = <Offset>[
      for (final g in _grain) Offset(g.dx * w, g.dy * h),
    ];
    canvas.drawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = Colors.white.withValues(alpha: grainOpacity)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );

    // Лёгкий блик сверху: LCD iPod всегда чуть бликовал стеклом корпуса.
    if (showGloss) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            Offset(0, h * 0.5),
            [
              Colors.white.withValues(alpha: 0.035),
              Colors.white.withValues(alpha: 0),
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_GraphitePainter old) =>
      old.base != base ||
      old.grainOpacity != grainOpacity ||
      old.showGloss != showGloss;
}