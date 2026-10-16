import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/service_badge.dart';
import '../../design/tokens/design_tokens.dart';
import 'ios_cover_flow.dart';
import 'player_controls.dart';

/// Плеер iOS-скина: обложки очереди (Cover Flow) и подписи под ними.
///
/// Вёрстка плотная и вертикальная — так выглядит плеер в iOS: картинка,
/// название, прогресс, ряд управления, ряд инструментов. Всё, что касается
/// состояния, приходит в [PlayerUi]: экран выше — единственный, кто знает про
/// плеер, поэтому этот виджет тестируется обычным `pumpWidget`.
class IosPlayerView extends StatelessWidget {
  const IosPlayerView({super.key, required this.ui});

  final PlayerUi ui;

  @override
  Widget build(BuildContext context) {
    final tokens = ui.tokens;
    return Column(
      children: [
        // Обложки занимают всё свободное место: на iOS это главный объект
        // экрана, и жёстко задавать им высоту нельзя — на низком экране
        // подписи всё равно должны поместиться.
        Expanded(
          child: IosCoverFlow(
            tokens: tokens,
            items: ui.queue,
            index: ui.index,
            direction: ui.direction,
            onIndexChanged: ui.onSelectIndex,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space16),
          child: Column(
            children: [
              SizedBox(height: tokens.space8),
              Text(
                ui.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tokens.title.copyWith(color: tokens.textPrimary),
              ),
              SizedBox(height: tokens.space2),
              PlayerLink(
                tokens: tokens,
                text: ui.track.artist,
                style: tokens.caption.copyWith(color: tokens.textSecondary),
                semanticLabel: 'Исполнитель: ${ui.track.artist}',
                onTap: ui.onArtist,
              ),
              if ((ui.track.album ?? '').isNotEmpty) ...[
                SizedBox(height: tokens.space2),
                PlayerLink(
                  tokens: tokens,
                  text: ui.track.album!,
                  style: tokens.micro.copyWith(color: tokens.textTertiary),
                  semanticLabel: 'Альбом: ${ui.track.album}',
                  leadingIcon: PlayerLinkIcon.album,
                  onTap: ui.onAlbum,
                ),
              ],
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
              SizedBox(height: tokens.space12),
              IosPlayerProgress(
                tokens: tokens,
                duration: ui.duration,
                onSeek: ui.onSeek,
              ),
              SizedBox(height: tokens.space8),
              PlayerControls(
                tokens: tokens,
                isPlaying: ui.isPlaying,
                isLoading: ui.isLoading,
                shuffleOn: ui.shuffleOn,
                repeatActive: ui.repeatActive,
                repeatOne: ui.repeatOne,
                onTogglePlay: ui.onTogglePlay,
                onPrev: ui.onPrev,
                onNext: ui.onNext,
                onShuffle: ui.onShuffle,
                onRepeat: ui.onCycleRepeat,
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
      ],
    );
  }
}

/// Полоса прогресса iOS: стандартный Slider плюс времена micro-шрифтом.
///
/// Отдельный [Consumer] внутри: позиция обновляется несколько раз в секунду,
/// и если подписаться на неё всем экраном, перестраивается весь плеер вместе
/// с обложками — заметно глазу и дороже по батарее.
class IosPlayerProgress extends ConsumerWidget {
  const IosPlayerProgress({
    super.key,
    required this.tokens,
    required this.duration,
    required this.onSeek,
  });

  final DesignTokens tokens;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final pos = ref.watch(positionProvider).value ?? Duration.zero;
        final max = duration.inMilliseconds.toDouble();
        final value =
            pos.inMilliseconds.clamp(0, max <= 0 ? 1 : max).toDouble();
        return Column(
          children: [
            SliderTheme(
              // Полоса iOS — скруглённая: у прямой нет «конца», глазу не на что
              // опереться, и она читается как отрезок, а не как шкала.
              data: SliderThemeData(
                trackShape: const RoundedRectSliderTrackShape(),
                activeTrackColor: tokens.accent,
                inactiveTrackColor: tokens.separator,
                thumbColor: tokens.accent,
                trackHeight: 4,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: max > 0 ? value : 0,
                max: max > 0 ? max : 1,
                onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatMediaTime(pos),
                  style: tokens.micro.copyWith(color: tokens.textTertiary),
                ),
                Text(
                  formatMediaTime(duration),
                  style: tokens.micro.copyWith(color: tokens.textTertiary),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}