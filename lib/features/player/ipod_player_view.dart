import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/player_visualizer.dart';
import '../../core/widgets/service_badge.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/tokens/design_tokens.dart';
import 'player_controls.dart';

/// Плеер iPod-скина: классическая раскладка «обложка — подписи — ряд —
/// прогресс» в обрамлении графита.
///
/// Отличие от iOS-версии не в логике, а в обрамлении: зерно и блик корпуса,
/// монохромные подписи LCD и панель без скруглений. Ряд управления — тот же
/// самый (см. [PlayerControls]): решение владельца проекта, управление должно
/// быть одинаковым в обеих темах.
class IpodPlayerView extends StatelessWidget {
  const IpodPlayerView({super.key, required this.ui});

  final PlayerUi ui;

  /// Обложка занимает 64 % ширины: на монохромном экране картинка — единственный
  /// источник цвета, её не ущемляем. Второе ограничение — высота: на низком
  /// экране обложка не должна вытеснить подписи и ряд управления.
  static const double _coverShare = 0.64;
  static const double _coverHeightShare = 0.40;

  /// Высота спектра: полосы должны читаться, но не спорить с обложкой.
  static const double _spectrumHeight = 22;

  @override
  Widget build(BuildContext context) {
    final tokens = ui.tokens;
    return GraphiteBackground(
      base: tokens.background,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final cover = math.min(
              c.maxWidth * _coverShare,
              c.maxHeight * _coverHeightShare,
            );
            return SingleChildScrollView(
              // Прокрутка — страховка для низких экранов и крупного шрифта:
              // лучше подпись уедет вниз, чем ряд управления станет недоступен.
              child: ConstrainedBox(
                // Колонка короткая, а экран высокий: без этого ограничения она
                // липла к верхнему краю и оставляла внизу пустую треть экрана
                // (замер: 237 px на 780). Теперь она занимает весь экран и
                // центрируется, а на низком экране прокрутка всё ещё работает.
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space16,
                    vertical: tokens.space8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Cover(
                        tokens: tokens,
                        url: ui.track.artworkUrl,
                        seed: ui.track.uid,
                        size: cover,
                      ),
                      SizedBox(height: tokens.space16),
                      _LcdLabels(ui: ui),
                      SizedBox(height: tokens.space8),
                      ServicePill(ui.service, origin: ui.originService),
                      if (ui.error != null) ...[
                        SizedBox(height: tokens.space8),
                        PlayerErrorBar(
                          tokens: tokens,
                          message: ui.error!,
                          onRetry: ui.onRetry,
                        ),
                      ],
                      SizedBox(height: tokens.space8),
                      // Спектр живёт только здесь: на монохромном экране он
                      // читается как «идёт звук», а в iOS место освободил Cover Flow.
                      SizedBox(
                        height: _spectrumHeight,
                        child: ui.isPlaying
                            ? PlayerVisualizer(
                                playing: true,
                                color: tokens.accent,
                                height: _spectrumHeight,
                              )
                            : null,
                      ),
                      SizedBox(height: tokens.space8),
                      _ControlsPanel(ui: ui),
                      SizedBox(height: tokens.space12),
                      IpodPlayerProgress(
                        tokens: tokens,
                        duration: ui.duration,
                        onSeek: ui.onSeek,
                      ),
                      SizedBox(height: tokens.space8),
                      PlayerTools(
                        tokens: tokens,
                        liked: ui.liked,
                        disliked: ui.disliked,
                        downloaded: ui.downloaded,
                        downloading: ui.downloading,
                        downloadProgress: ui.downloadProgress,
                        onLyrics: ui.onLyrics,
                        onQueue: ui.onQueue,
                        onDownload: ui.onDownload,
                        onAddToPlaylist: ui.onAddToPlaylist,
                        onLike: ui.onLike,
                        onDislike: ui.onDislike,
                      ),
                      SizedBox(height: tokens.space12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Обложка в корпусе: рамка в один пиксель отделяет её от графита, иначе
/// картинка «вплавливается» в фон.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.tokens,
    required this.url,
    required this.seed,
    required this.size,
  });

  final DesignTokens tokens;
  final String? url;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.separator),
        ),
        child: Artwork(url, size: size, radius: tokens.radiusSm, seed: seed),
      ),
    );
  }
}

/// LCD-подписи: исполнитель, название, альбом.
///
/// Порядок — как на самом iPod: кто, что, где. Кегли берутся из токенов
/// micro / caption, а разрядка у micro уже зашита в токен — поэтому подписи
/// читаются как строка на LCD, а не как обычный текст приложения.
class _LcdLabels extends StatelessWidget {
  const _LcdLabels({required this.ui});

  final PlayerUi ui;

  @override
  Widget build(BuildContext context) {
    final tokens = ui.tokens;
    return Column(
      children: [
        PlayerLink(
          tokens: tokens,
          text: ui.track.artist,
          style: tokens.micro.copyWith(color: tokens.textTertiary),
          semanticLabel: 'Исполнитель: ${ui.track.artist}',
          onTap: ui.onArtist,
        ),
        SizedBox(height: tokens.space2),
        // Название — единственная подпись без действия: открывать его некуда,
        // и делать из него «ссылку» было бы обещанием, которое не выполняется.
        Text(
          ui.track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: tokens.caption.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if ((ui.track.album ?? '').isNotEmpty) ...[
          SizedBox(height: tokens.space2),
          PlayerLink(
            tokens: tokens,
            text: ui.track.album!,
            style: tokens.micro.copyWith(color: tokens.textSecondary),
            semanticLabel: 'Альбом: ${ui.track.album}',
            leadingIcon: PlayerLinkIcon.album,
            onTap: ui.onAlbum,
          ),
        ],
      ],
    );
  }
}

/// Ряд управления в обрамлении корпуса: панель токена, тонкая рамка, без
/// скруглений. Радиус берётся из токена iPod (ноль) — если бы здесь стоял
/// iOS-радиус, панель выглядела бы как карточка внутри iPod.
class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({required this.ui});

  final PlayerUi ui;

  @override
  Widget build(BuildContext context) {
    final tokens = ui.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space8,
        vertical: tokens.space12,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.separator),
      ),
      child: PlayerControls(
        tokens: tokens,
        isPlaying: ui.isPlaying,
        isLoading: ui.isLoading,
        shuffleOn: ui.shuffleOn,
        repeatActive: ui.repeatActive,
        repeatOne: ui.repeatOne,
        // Кнопка чуть меньше, чем в iOS: в корпусе iPod ряд уже.
        diameter: 56,
        onTogglePlay: ui.onTogglePlay,
        onPrev: ui.onPrev,
        onNext: ui.onNext,
        onShuffle: ui.onShuffle,
        onRepeat: ui.onCycleRepeat,
      ),
    );
  }
}

/// Прогресс iPod: тонкая полоса и времена шрифтом LCD.
///
/// Собственный [Consumer], как и в iOS: позиция тикает несколько раз в секунду
/// и не должна перестраивать обложку и подписи.
class IpodPlayerProgress extends ConsumerWidget {
  const IpodPlayerProgress({
    super.key,
    required this.tokens,
    required this.duration,
    required this.onSeek,
  });

  final DesignTokens tokens;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// Высота полосы с запасом на палец: сама полоса тонкая, но тянуть её
  /// приходится пальцем.
  static const double _barHeight = 22;

  /// Толщина полосы: у iPod шкала тонкая, «LCD-тонкая».
  static const double _trackHeight = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final pos = ref.watch(positionProvider).value ?? Duration.zero;
        final total = duration.inMilliseconds;
        final fraction =
            total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                void seekAt(double dx) {
                  if (total <= 0) return;
                  final f = (dx / c.maxWidth).clamp(0.0, 1.0);
                  onSeek(Duration(milliseconds: (total * f).round()));
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => seekAt(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
                  child: SizedBox(
                    height: _barHeight,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            width: c.maxWidth,
                            height: _trackHeight,
                            color: tokens.separator,
                          ),
                          Container(
                            width:
                                c.maxWidth * (fraction == 0 ? 0.0 : fraction),
                            height: _trackHeight,
                            color: tokens.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatMediaTime(pos),
                  style: tokens.micro.copyWith(color: tokens.textSecondary),
                ),
                Text(
                  formatMediaTime(duration),
                  style: tokens.micro.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
