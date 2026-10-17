import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/widgets/mini_player.dart';
import '../common/track_row.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/track.dart';
import '../../l10n/gen/app_localizations.dart';

/// Треклист альбома. Ключ семьи — трек-зерно (по нему агрегатор знает источник
/// и albumId). Нативно грузится у Яндекса; у остальных — фолбэк на поиск.
final _albumTracksProvider =
    FutureProvider.family<List<Track>, Track>((ref, seed) async {
  return ref.read(aggregatorProvider).albumTracks(seed);
});

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.seed});

  /// Трек, с которого открыли альбом (даёт название, источник и albumId).
  final Track seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(_albumTracksProvider(seed));
    final l10n = AppLocalizations.of(context)!;
    final title =
        (seed.album ?? '').isNotEmpty ? seed.album! : l10n.albumFallbackTitle;
    final album = AlbumResult.fromSeed(seed);
    final lib = ref.watch(libraryProvider);
    final liked = lib.isAlbumLiked(album);
    final disliked = lib.isAlbumDisliked(album);
    final t = SkinScope.of(context).tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.thumbDown,
                color: disliked ? t.warning : t.textSecondary),
            tooltip: disliked ? 'Убрать дизлайк' : 'Не нравится',
            onPressed: () =>
                ref.read(libraryProvider).toggleDislikeAlbum(album),
          ),
          IconButton(
            icon: AppIcon(liked ? AppIcons.heartFilled : AppIcons.heart,
                color: liked ? t.danger : t.textSecondary),
            tooltip: liked ? 'Убрать из избранного' : 'В избранное',
            onPressed: () => ref.read(libraryProvider).toggleLikeAlbum(album),
          ),
          IconButton(
            icon: AppIcon(AppIcons.download, color: t.textSecondary),
            tooltip: 'Скачать альбом',
            onPressed: () {
              final list = tracks.value;
              final downloads = ref.read(downloadsProvider);
              if (list != null && list.isNotEmpty && !downloads.playlistBusy) {
                downloads.downloadPlaylist(title, list);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Скачивание «$title»…')));
              }
            },
          ),
          IconButton(
            icon: AppIcon(AppIcons.radio, color: t.textSecondary),
            tooltip: l10n.albumRadioTooltip,
            onPressed: () {
              final list = tracks.value;
              if (list != null && list.isNotEmpty) {
                ref.read(playbackProvider).startRadio(list.first, list);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: tracks.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.loadErrorGeneric(e.toString()),
                style: TextStyle(color: t.textSecondary)),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(l10n.albumTracksEmpty,
                  style: TextStyle(color: t.textSecondary)),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => SkinTrackRow(
              track: list[i],
              onTap: () => playTrack(ref, context, list[i], queue: list),
            ),
          );
        },
      ),
    );
  }
}
