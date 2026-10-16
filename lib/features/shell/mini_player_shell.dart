import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/theme_settings.dart';
import '../../core/widgets/artwork.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/tokens/ipod_tokens.dart';
import '../../design/tokens/ios_tokens.dart';
import '../../domain/models/track.dart';

/// Мини-плеер оболочки: тот же вид, что и у любого другого экрана, но живёт
/// внутри каркаса скина — над нижней панелью iOS и под меню iPod.
///
/// Общее у обоих видов: обложка, название, артист, кнопка play/pause, тап открывает
/// полноэкранный плеер и свайп вверх открывает его же. Различаются они только
/// формой: iOS-скин показывает мини-плеер «карточкой» с закруглёнными углами и
/// акцентной кнопкой, iPod — прямой строкой прибора с LCD-подписью времени.
class ShellMiniPlayer extends ConsumerWidget {
  const ShellMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pc = ref.watch(playbackProvider);
    final track = pc.current;
    if (track == null) return const SizedBox.shrink();

    // Скин берём из провайдера, а не только из SkinScope: мини-плеер ездит и по
    // экранам вне оболочки (альбом, артист, чарты), где SkinScope может и не
    // стоять, а выглядеть он обязан всё равно по текущей теме.
    final scoped = SkinScope.maybeOf(context);
    final skin = ref.watch(currentSkinProvider);
    final effective = scoped ?? skin;
    final tokens = effective.tokens;
    final showEq = ref.watch(themeSettingsProvider).animLevel != AnimLevel.min;

    return SkinScope(
      skin: effective,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => context.push(Routes.player),
          // Свайп вверх — второй способ открыть плеер: на большом экране
          // мини-плеер находится далеко от верхней половины, и тянуть его
          // пальцем до кнопки плея не нужно.
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -250) context.push(Routes.player);
          },
          child: effective.id == SkinId.ipod
              ? IpodMiniPlayer(
                  tokens: tokens,
                  track: track,
                  isPlaying: pc.isPlaying,
                  isLoading: pc.isLoading,
                  onTogglePlay: pc.togglePlay,
                )
              : IosMiniPlayer(
                  tokens: tokens,
                  track: track,
                  isPlaying: pc.isPlaying,
                  isLoading: pc.isLoading,
                  showEqualizer: showEq,
                  onTogglePlay: pc.togglePlay,
                ),
        ),
      ),
    );
  }
}

/// Мини-плеер iOS: плавающая карточка со скруглением токена.
///
/// Отступы внутри и снаружи заданы токенами, а не числами: у iPod этот же вид
/// должен схлопнуться в строку прибора, и если бы геометрия была зашита, iPod
/// получил бы карточку с радиусом iOS.
class IosMiniPlayer extends StatelessWidget {
  const IosMiniPlayer({
    super.key,
    required this.tokens,
    required this.track,
    required this.isPlaying,
    required this.isLoading,
    required this.onTogglePlay,
    this.showEqualizer = true,
  });

  final DesignTokens tokens;
  final Track track;
  final bool isPlaying;
  final bool isLoading;
  final bool showEqualizer;

  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Padding(
      // «Отрыв» от таб-бара: карточка должна читаться как плавающий слой, а не
      // как ещё одна строка над панелью.
      padding: EdgeInsets.fromLTRB(t.space8, t.space4, t.space8, t.space8),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusLg),
            border: Border.all(color: t.separator),
          ),
          padding: EdgeInsets.all(t.space8),
          child: Row(
            children: [
              _Artwork(
                url: track.artworkUrl,
                seed: track.uid,
                // Размер обложки — свойство конкретного скина, а не общий
                // контракт токенов: iOS держит ряд плотным, iPod — крупным.
                size: IosTokens.coverSize,
                radius: t.radiusMd,
              ),
              SizedBox(width: t.space12),
              Expanded(
                child: _TrackLabels(
                  tokens: t,
                  track: track,
                  titleStyle: t.body,
                  artistStyle: t.caption,
                  artistColor: t.textSecondary,
                ),
              ),
              if (isPlaying && showEqualizer) ...[
                _EqualizerBars(color: t.accent, radius: t.radiusPill),
                SizedBox(width: t.space8),
              ],
              _PlayButton(
                tokens: t,
                icon: _playIcon(isPlaying, isLoading),
                color: t.accent,
                iconColor: t.accentOn,
                onTap: onTogglePlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Мини-плеер iPod: строка «прибора» — без скруглений, с разделителями и
/// подписью времени трека, как на LCD корпуса.
///
/// Здесь намеренно нет индикатора эквалайзера: строка и так несёт три прибора
/// (обложка, время, кнопка), а полоски эквалайзера стали бы четвёртым и
/// перестали читаться. Время трека для этого и оставлено — на iPod время
/// было главным, что показывает плеер.
class IpodMiniPlayer extends StatelessWidget {
  const IpodMiniPlayer({
    super.key,
    required this.tokens,
    required this.track,
    required this.isPlaying,
    required this.isLoading,
    required this.onTogglePlay,
  });

  final DesignTokens tokens;
  final Track track;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        // Разделитель сверху: строка прибора отделена от содержимого меню, как
        // граница корпуса. Ширина — 1 px, это не «толщина» темы.
        border: Border(top: BorderSide(color: t.separator)),
      ),
      padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: t.space8),
      child: Row(
        children: [
          _Artwork(
            url: track.artworkUrl,
            seed: track.uid,
            size: IpodTokens.coverSize,
            // Скругление обложки — тоже радиус токена: на iPod он нулевой, и
            // обложка становится прямоугольной плиткой, как на корпусе.
            radius: t.radiusSm,
          ),
          SizedBox(width: t.space12),
          Expanded(
            child: _TrackLabels(
              tokens: t,
              track: track,
              titleStyle: t.body,
              artistStyle: t.micro,
              artistColor: t.textSecondary,
            ),
          ),
          _CellDivider(tokens: t),
          _LcdTime(tokens: t, track: track),
          _CellDivider(tokens: t),
          _PlayButton(
            tokens: t,
            icon: _playIcon(isPlaying, isLoading),
            // Инвертированный блок: на монохромном экране это единственный
            // способ выделить действие без цвета.
            color: t.accent,
            iconColor: t.accentOn,
            onTap: onTogglePlay,
          ),
        ],
      ),
    );
  }
}

/// Обложка трека. Собственный виджет, а не [Artwork] из core, потому что
/// радиус здесь обязан быть радиусом ТОКЕНА: передав null, мы бы вернули
/// радиус из настроек Material-темы и снова привязали вид к чужой системе.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.url,
    required this.seed,
    required this.size,
    required this.radius,
  });

  final String? url;
  final String seed;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Artwork(url, size: size, seed: seed, radius: radius);
  }
}

/// Название и артист: общая часть обоих видов. Формат текста отличается
/// (кегль и цвет), поэтому стили передаются параметрами.
class _TrackLabels extends StatelessWidget {
  const _TrackLabels({
    required this.tokens,
    required this.track,
    required this.titleStyle,
    required this.artistStyle,
    required this.artistColor,
  });

  final DesignTokens tokens;
  final Track track;
  final TextStyle titleStyle;
  final TextStyle artistStyle;
  final Color artistColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle.copyWith(color: tokens.textPrimary),
        ),
        SizedBox(height: tokens.space2),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: artistStyle.copyWith(color: artistColor),
        ),
      ],
    );
  }
}

/// LCD-подпись времени трека: `м:сс` или `--:--`, если длительность неизвестна.
///
/// Шрифт — токенный микро, у iPod с его трекингом 0.6: разрядка и есть
/// «матрица», ради которой этот вид вообще выбран.
class _LcdTime extends StatelessWidget {
  const _LcdTime({required this.tokens, required this.track});

  final DesignTokens tokens;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final duration = track.duration;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppIcons.clock, size: 16, color: tokens.textTertiary),
        SizedBox(height: tokens.space2),
        Text(
          duration == null ? '--:--' : _formatTime(duration),
          style: tokens.micro.copyWith(color: tokens.textPrimary),
        ),
      ],
    );
  }
}

/// Вертикальный разделитель между «приборами» строки iPod.
class _CellDivider extends StatelessWidget {
  const _CellDivider({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Ширина 1 px — это толщина линии, а не мера темы: разделитель на iPod
      // должен остаться линией, пока его не увеличат в разы.
      width: 1,
      height: IpodTokens.rowHeight,
      color: tokens.separator,
      margin: EdgeInsets.symmetric(horizontal: tokens.space8),
    );
  }
}

/// Кнопка play/pause.
///
/// Форма приходит из токенов: iOS рисует круглую акцентную кнопку, iPod —
/// прямоугольный инвертированный блок (radiusSm у него нулевой).
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.tokens,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final DesignTokens tokens;
  final AppIconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.radiusPill);
    return Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          // Сторона кнопки — сумма двух отступов токенов, а не число в коде:
          // плотному iOS хватает меньшего, чем iPod-«прибору».
          width: tokens.space24 + tokens.space16,
          height: tokens.space24 + tokens.space16,
          child: Center(child: AppIcon(icon, size: 22, color: iconColor)),
        ),
      ),
    );
  }
}

/// Индикатор играющего трека: четыре полоски, каждая в своей фазе.
///
/// Анимация не «плавает» сама по таймеру виджета — фазы выведены из одного
/// контроллера через сдвиг, поэтому полоски всегда согласованы между собой и
/// не расходятся после пересборки.
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    return SizedBox(
      width: 16,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) {
            final phase = (_c.value + i * 0.22) % 1.0;
            final h = 4 + (10 * (0.5 - (phase - 0.5).abs()) * 2);
            return Container(
              width: 2.5,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: radius,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Иконка кнопки: во время загрузки потока показываем синхронизацию вместо
/// play, чтобы кнопка не обещала действие, которое сейчас ничего не даст.
AppIconData _playIcon(bool isPlaying, bool isLoading) {
  if (isLoading) return AppIcons.sync;
  return isPlaying ? AppIcons.pause : AppIcons.play;
}

/// `м:сс` — формат экрана iPod (часы без ведущего нуля у минут, но с ним у
/// секунд).
String _formatTime(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}