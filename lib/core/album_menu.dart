import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'theme/app_colors.dart';
import 'widgets/artwork.dart';
import '../domain/models/album_result.dart';
import '../features/album/album_screen.dart';

/// Контекстное меню альбома (по долгому тапу на карточке в поиске/медиатеке):
/// открыть / лайк / дизлайк / скачать все треки альбома.
Future<void> showAlbumMenu(
    BuildContext context, WidgetRef ref, AlbumResult album) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface1,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(album.artworkUrl,
                size: 44, seed: album.uid, radius: 10),
            title: Text(album.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.white45)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.album),
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
              leading: Icon(liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? AppColors.danger : null),
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
              leading: Icon(
                  disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                  color: disliked ? AppColors.warning : null),
              title: Text(disliked ? 'Убрать дизлайк' : 'Не нравится'),
              onTap: () {
                r.read(libraryProvider).toggleDislikeAlbum(album);
                Navigator.pop(sheetCtx);
              },
            );
          }),
          ListTile(
            leading: const Icon(Icons.download),
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
