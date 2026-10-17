import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/icons/app_icons.dart';
import '../design/skin.dart';
import '../design/skin_registry.dart';
import 'providers.dart';
import 'widgets/artwork.dart';
import '../domain/models/album_result.dart';
import '../features/album/album_screen.dart';

/// Контекстное меню альбома (по долгому тапу на карточке в поиске/медиатеке):
/// открыть / лайк / дизлайк / скачать все треки альбома.
Future<void> showAlbumMenu(
    BuildContext context, WidgetRef ref, AlbumResult album) {
  // Модальное окно живёт вне дерева экрана — скин берём до открытия.
  final t = SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ios).tokens;
  return showModalBottomSheet(
    context: context,
    backgroundColor: t.surface,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(album.artworkUrl,
                size: 44, seed: album.uid, radius: t.radiusMd),
            title: Text(album.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textTertiary)),
          ),
          Divider(height: 1, color: t.separator),
          ListTile(
            leading: AppIcon(AppIcons.library, size: 20, color: t.textSecondary),
            title: const Text('Открыть альбом'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AlbumScreen(seed: album.toSeedTrack())));
            },
          ),
          Consumer(builder: (_, r, __) {
            final liked = r.watch(libraryProvider).isAlbumLiked(album);
            return ListTile(
              leading: AppIcon(liked ? AppIcons.heartFilled : AppIcons.heart,
                  size: 20, color: liked ? t.danger : t.textSecondary),
              title: Text(liked ? 'Убрать из избранного' : 'В избранное'),
              onTap: () {
                r.read(libraryProvider).toggleLikeAlbum(album);
                Navigator.pop(sheetCtx);
              },
            );
          }),
          Consumer(builder: (_, r, __) {
            final disliked = r.watch(libraryProvider).isAlbumDisliked(album);
            return ListTile(
              leading: AppIcon(AppIcons.thumbDown,
                  size: 20, color: disliked ? t.warning : t.textSecondary),
              title: Text(disliked ? 'Убрать дизлайк' : 'Не нравится'),
              onTap: () {
                r.read(libraryProvider).toggleDislikeAlbum(album);
                Navigator.pop(sheetCtx);
              },
            );
          }),
          ListTile(
            leading: AppIcon(AppIcons.download, size: 20, color: t.textSecondary),
            title: const Text('Скачать альбом'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _downloadAlbum(context, ref, album);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _downloadAlbum(
    BuildContext context, WidgetRef ref, AlbumResult album) async {
  if (ref.read(downloadsProvider).playlistBusy) return;
  final tracks =
      await ref.read(aggregatorProvider).albumTracks(album.toSeedTrack());
  if (!context.mounted) return;
  if (tracks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось получить треклист альбома')));
    return;
  }
  ref.read(downloadsProvider).downloadPlaylist(album.title, tracks);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Скачивание «${album.title}»…')));
}