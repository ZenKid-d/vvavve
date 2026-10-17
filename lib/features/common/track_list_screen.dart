import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_download_status.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../domain/models/track.dart';
import 'skin_controls.dart';
import 'track_row.dart';

/// Универсальный экран со списком треков: статический список или загрузчик.
/// Кнопки «Слушать всё» и «Радио», мини-плеер внизу.
class TrackListScreen extends ConsumerStatefulWidget {
  const TrackListScreen({
    super.key,
    required this.title,
    this.tracks,
    this.loader,
  });

  final String title;
  final List<Track>? tracks;
  final Future<List<Track>> Function()? loader;

  @override
  ConsumerState<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends ConsumerState<TrackListScreen> {
  List<Track>? _tracks;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.tracks != null) {
      _tracks = widget.tracks;
    } else if (widget.loader != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await widget.loader!();
      if (mounted) setState(() => _tracks = t);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    final tracks = _tracks;
    final downloads = ref.watch(downloadsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (tracks != null && tracks.isNotEmpty)
            IconButton(
              icon: AppIcon(AppIcons.download, color: t.textSecondary),
              tooltip: 'Скачать все треки',
              onPressed: downloads.playlistBusy
                  ? null
                  : () => ref
                      .read(downloadsProvider)
                      .downloadPlaylist(widget.title, tracks),
            ),
        ],
        bottom: downloads.playlistBusy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                    value: downloads.playlistProgress, color: t.accent),
              )
            : null,
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Ошибка: $_error',
                        style: TextStyle(color: t.textSecondary)),
                  ),
                )
              : (tracks == null || tracks.isEmpty)
                  ? Center(
                      child: Text('Пусто',
                          style: TextStyle(color: t.textSecondary)))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: SkinActionButton(
                                  label: 'Слушать всё',
                                  icon: AppIcons.play,
                                  filled: true,
                                  onPressed: () => playTrack(
                                      ref, context, tracks.first,
                                      queue: tracks),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SkinActionButton(
                                label: 'Радио',
                                icon: AppIcons.radio,
                                onPressed: () => ref
                                    .read(playbackProvider)
                                    .startRadio(tracks.first, tracks),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: tracks.length,
                            itemBuilder: (_, i) => SkinTrackRow(
                              track: tracks[i],
                              onTap: () => playTrack(ref, context, tracks[i],
                                  queue: tracks),
                              trailing: TrackDownloadStatus(tracks[i]),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
