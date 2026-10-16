import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/playlist_actions.dart' show showAddToPlaylistSheet;
import '../../core/providers.dart';
import '../../core/widgets/track_card.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart' show EmptyState;
import '../../domain/models/track.dart';
import '../../playback/audio_handler.dart' show LoopMode;
import '../album/album_screen.dart';
import '../artist/artist_screen.dart';
import '../common/track_list_screen.dart';
import 'equalizer_screen.dart';
import 'ios_player_view.dart';
import 'ipod_player_view.dart';
import 'lyrics_screen.dart';
import 'player_controls.dart';

/// Экран «Сейчас играет».
///
/// Экран не рисует ничего сам: он собирает состояние плеера в [PlayerUi] и
/// передаёт его одному из двух видов — iOS или iPod. Вся разница между темами
/// живёт в вёрстке, а логика (очередь, меню, таймер сна, дизлайк, загрузка)
/// остаётся здесь одна — иначе через месяц две версии плеера разойдутся.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  /// Направление смены трека: 1 — вперёд, -1 — назад. Нужно анимации подъёма
  /// обложки в Cover Flow, чтобы она шла в ту же сторону, что и переход.
  int _dir = 1;

  void _goNext() {
    setState(() => _dir = 1);
    ref.read(playbackProvider).next();
  }

  void _goPrev() {
    setState(() => _dir = -1);
    ref.read(playbackProvider).previous();
  }

  /// Скин берём из области скина, а если её нет (экран открыт маршрутом вне
  /// оболочки) — из выбранного пользователем. Иначе плеер был бы единственным
  /// экраном, который зависит от того, кто его открыл.
  Skin _skin(WidgetRef ref) =>
      SkinScope.maybeOf(context) ?? skinFor(ref.watch(skinProvider));

  @override
  Widget build(BuildContext context) {
    final skin = _skin(ref);
    final tokens = skin.tokens;
    final pc = ref.watch(playbackProvider);
    final track = pc.current;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: GestureDetector(
          // Жесты: свайп влево — след., вправо — пред., вниз — закрыть.
          // Горизонталь перехватывает Cover Flow в iOS-теме — там он и есть
          // «листание очереди», и результат тот же.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) {
              _goNext();
            } else if (v > 250) {
              _goPrev();
            }
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 300) context.pop();
          },
          child: Column(
            children: [
              _PlayerTopBar(
                tokens: tokens,
                onClose: () => context.pop(),
                onMore: track == null ? null : () => _moreMenu(track),
              ),
              Expanded(
                child: track == null
                    ? EmptyState(
                        tokens: tokens,
                        icon: AppIcons.musicNote,
                        title: 'Ничего не играет',
                        subtitle: 'Выберите трек — и плеер оживёт',
                      )
                    : switch (skin.id) {
                        SkinId.ios => IosPlayerView(ui: _ui(tokens, track)),
                        SkinId.ipod => IpodPlayerView(ui: _ui(tokens, track)),
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Собирает [PlayerUi] из состояния плеера. Отдельный метод — чтобы обе
  /// ветки switch читались одинаково и ни одна не «забыла» поле.
  PlayerUi _ui(DesignTokens tokens, Track track) {
    final pc = ref.read(playbackProvider);
    final queue = pc.queue;
    final downloads = ref.watch(downloadsProvider);
    final uid = track.uid;
    return PlayerUi(
      tokens: tokens,
      track: track,
      queue: queue,
      index: queue.indexWhere((t) => t.uid == uid),
      direction: _dir,
      isPlaying: pc.isPlaying,
      isLoading: pc.isLoading,
      shuffleOn: pc.isShuffle,
      repeatActive: pc.repeatMode != LoopMode.off,
      repeatOne: pc.repeatMode == LoopMode.one,
      duration: pc.duration,
      error: pc.error,
      liked: ref.watch(libraryProvider).isLiked(track),
      disliked: ref.watch(recsStoreProvider).isDisliked(track),
      downloaded: downloads.isDownloaded(uid),
      downloading: downloads.isDownloading(uid),
      downloadProgress:
          downloads.isDownloading(uid) ? downloads.progressFor(uid) : null,
      service: pc.playingVia ?? track.source,
      originService: pc.playingVia != null ? track.source : null,
      onClose: () => context.pop(),
      onMore: () => _moreMenu(track),
      onLyrics: () => _open(() => LyricsScreen(track: track)),
      onQueue: () => _showQueue(track),
      onDownload: () => _toggleDownload(track),
      onAddToPlaylist: () => showAddToPlaylistSheet(context, ref, track),
      onLike: () => ref.read(libraryProvider).toggleLike(track),
      onDislike: () => _dislike(track),
      onArtist: () => _open(() => ArtistScreen(artist: track.artist)),
      onAlbum: () => _open(() => AlbumScreen(seed: track)),
      onSelectIndex: (i) => _selectFromQueue(queue, i),
      onTogglePlay: () => ref.read(playbackProvider).togglePlay(),
      onPrev: _goPrev,
      onNext: _goNext,
      onShuffle: () => ref.read(playbackProvider).toggleShuffle(),
      onCycleRepeat: () => ref.read(playbackProvider).cycleRepeat(),
      onSeek: (d) => ref.read(playbackProvider).seek(d),
      onRetry: () => ref.read(playbackProvider).retry(),
    );
  }

  /// Выбор трека прямо из Cover Flow: играем его с текущей очередью, чтобы
  /// дальше листалось то, что пользователь уже собирал.
  void _selectFromQueue(List<Track> queue, int index) {
    if (index < 0 || index >= queue.length) return;
    // Листание очереди — движение вперёд, даже если выбран трек левее текущего:
    // направление здесь нужно только для анимации подъёма обложки.
    setState(() => _dir = 1);
    ref.read(playbackProvider).playTrack(queue[index], queue: queue);
  }

  /// Открытие экрана-ссылки. Именно push, а не `context.push`: это не
  /// навигационный раздел приложения, а продолжение просмотра трека.
  ///
  /// Билдер без параметров — потому что ни один из этих экранов не зависит от
  /// контекста роута, а тащить `BuildContext` ради пустой заглушки смысла нет.
  void _open(Widget Function() builder) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => builder()),
    );
  }

  void _toggleDownload(Track track) {
    final dl = ref.read(downloadsProvider);
    if (dl.isDownloaded(track.uid)) {
      dl.remove(track.uid);
    } else if (!dl.isDownloading(track.uid)) {
      dl.download(track);
    }
  }

  /// Свежий дизлайк текущего трека — сразу проматываем дальше: иначе человек
  /// остаётся слушать то, что только что отверг.
  Future<void> _dislike(Track track) async {
    final wasDisliked = ref.read(recsStoreProvider).isDisliked(track);
    await ref.read(recsStoreProvider).toggleDislike(track);
    if (!wasDisliked && ref.read(playbackProvider).current?.uid == track.uid) {
      _goNext();
    }
  }

  void _showQueue(Track current) {
    final tokens = _skin(ref).tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) {
        final pc = ref.read(playbackProvider);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, scroll) => ListView(
            controller: scroll,
            children: [
              Padding(
                padding: EdgeInsets.all(tokens.space16),
                child: Text(
                  'Очередь',
                  style: tokens.title.copyWith(color: tokens.textPrimary),
                ),
              ),
              for (final t in pc.queue)
                TrackRow(
                  track: t,
                  active: t.uid == current.uid,
                  onTap: () {
                    pc.playTrack(t, queue: pc.queue);
                    Navigator.of(sheetCtx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Меню «•••»: всё, что не помещается в ряд плеера.
  void _moreMenu(Track track) {
    final tokens = _skin(ref).tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              tokens: tokens,
              icon: AppIcons.radio,
              title: 'Радио по этому треку',
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final list = await ref
                    .read(recommendationServiceProvider)
                    .radioFrom(track);
                await ref.read(playbackProvider).startRadio(track, list);
              },
            ),
            _menuItem(
              tokens: tokens,
              icon: AppIcons.sparkles,
              title: 'Похожие треки',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _open(
                  () => TrackListScreen(
                    title: 'Похоже на «${track.title}»',
                    loader: () => ref
                        .read(recommendationServiceProvider)
                        .similarTo(track),
                  ),
                );
              },
            ),
            _menuItem(
              tokens: tokens,
              icon: AppIcons.sync,
              title: 'Скорость воспроизведения',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _speedSheet();
              },
            ),
            // Эквалайзер — андроидный аудиоэффект (AndroidEqualizer поверх
            // just_audio), поэтому пункт есть только на Android.
            _menuItem(
              tokens: tokens,
              icon: AppIcons.volume,
              title: 'Эквалайзер',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _open(() => const EqualizerScreen());
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final timer = ref.watch(sleepTimerProvider);
                final rem = timer.remaining;
                final afterTrack =
                    ref.watch(playbackProvider).sleepAfterTrack;
                final active = timer.active || afterTrack;
                final subtitle = afterTrack
                    ? 'До конца трека'
                    : (rem != null ? 'Осталось ${formatMediaTime(rem)}' : null);
                return _menuItem(
                  tokens: tokens,
                  icon: AppIcons.clock,
                  title: 'Таймер сна',
                  subtitle: subtitle,
                  trailing: active
                      ? TextButton(
                          onPressed: () {
                            ref.read(sleepTimerProvider).cancel();
                            ref.read(playbackProvider)
                              ..setSleepAfterTrack(false)
                              ..setVolume(1);
                          },
                          child: Text(
                            'Стоп',
                            style: tokens.caption.copyWith(color: tokens.accent),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _sleepSheet();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sleepSheet() {
    final tokens = _skin(ref).tokens;
    const options = {'15 минут': 15, '30 минут': 30, '45 минут': 45, '1 час': 60};
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Text(
                'Уснуть через',
                style: tokens.title.copyWith(color: tokens.textPrimary),
              ),
            ),
            _menuItem(
              tokens: tokens,
              icon: AppIcons.musicNote,
              title: 'До конца текущего трека',
              onTap: () {
                ref.read(sleepTimerProvider).cancel();
                ref.read(playbackProvider).setSleepAfterTrack(true);
                Navigator.of(sheetCtx).pop();
                _snack('Пауза после текущего трека');
              },
            ),
            for (final e in options.entries)
              _menuItem(
                tokens: tokens,
                icon: AppIcons.clock,
                title: e.key,
                subtitle: 'С плавным затуханием в конце',
                onTap: () {
                  final pc = ref.read(playbackProvider);
                  pc.setSleepAfterTrack(false);
                  const fadeMs = 30000; // затухание в последние 30 сек
                  ref.read(sleepTimerProvider).start(
                    Duration(minutes: e.value),
                    () {
                      pc.pause();
                      pc.setVolume(1); // вернуть громкость для след. запуска
                    },
                    onTick: (rem) {
                      final v = rem.inMilliseconds >= fadeMs
                          ? 1.0
                          : (rem.inMilliseconds / fadeMs).clamp(0.0, 1.0);
                      pc.setVolume(v);
                    },
                  );
                  Navigator.of(sheetCtx).pop();
                  _snack('Таймер сна: ${e.key}');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _speedSheet() {
    final tokens = _skin(ref).tokens;
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final current = ref.read(playbackProvider).speed;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Text(
                'Скорость',
                style: tokens.title.copyWith(color: tokens.textPrimary),
              ),
            ),
            for (final s in speeds)
              _menuItem(
                tokens: tokens,
                icon: AppIcons.sync,
                title: '${s}x',
                // Отметка текущей скорости — галочкой акцента: список короткий,
                // сравнивать цифры не нужно.
                trailing: (s - current).abs() < 0.01
                    ? AppIcon(AppIcons.check, color: tokens.accent, size: 18)
                    : null,
                onTap: () {
                  ref.read(playbackProvider).setSpeed(s);
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Пункт шторки меню. Свой виджет, а не ListTile: ListTile тащит за собой
  /// Material-тему (шрифты, радиусы, цвета состояний), и тогда шторка плеера
  /// выглядела бы как чужой экран.
  Widget _menuItem({
    required DesignTokens tokens,
    required AppIconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space16,
            vertical: tokens.space12,
          ),
          child: Row(
            children: [
              AppIcon(icon, color: tokens.accent, size: 22),
              SizedBox(width: tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: tokens.body.copyWith(color: tokens.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: tokens.caption
                            .copyWith(color: tokens.textSecondary),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Шапка плеера: закрыть — заголовок — меню.
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.tokens,
    required this.onClose,
    required this.onMore,
  });

  final DesignTokens tokens;
  final VoidCallback onClose;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: AppIcon(
            AppIcons.chevronDown,
            size: 22,
            color: tokens.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            'СЕЙЧАС ИГРАЕТ',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.micro.copyWith(color: tokens.textTertiary),
          ),
        ),
        IconButton(
          onPressed: onMore,
          icon: AppIcon(
            AppIcons.more,
            size: 22,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}