import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/icons/app_icons.dart';
import '../design/skin.dart';
import '../design/skin_registry.dart';
import 'playlist_actions.dart' show showAddToPlaylistSheet;
import 'providers.dart';
import 'share_card.dart';
import 'widgets/artwork.dart';
import '../domain/models/track.dart';
import '../features/album/album_screen.dart';

/// Контекстное меню трека (по долгому тапу): играть следующим / в очередь /
/// радио / скачать / в плейлист / избранное.
Future<void> showTrackMenu(
    BuildContext context, WidgetRef ref, Track track) {
  // Меню живёт вне дерева экрана (модальное окно), поэтому скин берём
  // ДО открытия — у sheet-контекста SkinScope может не оказаться.
  final t = SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ios).tokens;
  return showModalBottomSheet(
    context: context,
    backgroundColor: t.surface,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(track.artworkUrl,
                size: 44, seed: track.uid, radius: t.radiusMd),
            title: Text(track.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textTertiary)),
          ),
          Divider(height: 1, color: t.separator),
          ListTile(
            leading: AppIcon(AppIcons.play, size: 20, color: t.accent),
            title: const Text('Играть следующим'),
            onTap: () {
              ref.read(playbackProvider).playNext(track);
              ref.read(recsStoreProvider).recordRepeat(track);
              Navigator.pop(sheetCtx);
              _snack(context, 'Играет следующим');
            },
          ),
          ListTile(
            leading: AppIcon(AppIcons.queue, size: 20, color: t.textSecondary),
            title: const Text('Добавить в очередь'),
            onTap: () {
              ref.read(playbackProvider).addToQueue(track);
              ref.read(recsStoreProvider).recordRepeat(track);
              Navigator.pop(sheetCtx);
              _snack(context, 'Добавлено в очередь');
            },
          ),
          ListTile(
            leading: AppIcon(AppIcons.radio, size: 20, color: t.textSecondary),
            title: const Text('Радио по треку'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              _snack(context, 'Собираю радио…');
              final list = await ref
                  .read(recommendationServiceProvider)
                  .radioFrom(track);
              await ref.read(playbackProvider).startRadio(track, list);
              ref.read(libraryProvider).pushHistory(track);
              if (context.mounted) context.push('/player');
            },
          ),
          Consumer(builder: (_, r, __) {
            final done = r.watch(downloadsProvider).isDownloaded(track.uid);
            return ListTile(
              leading: AppIcon(done ? AppIcons.downloadDone : AppIcons.download,
                  size: 20,
                  color: done ? t.success : t.textSecondary),
              title: Text(done ? 'Уже скачано' : 'Скачать'),
              enabled: !done,
              onTap: () {
                r.read(downloadsProvider).download(track);
                Navigator.pop(sheetCtx);
                _snack(context, 'Скачивание…');
              },
            );
          }),
          ListTile(
            leading:
                AppIcon(AppIcons.plus, size: 20, color: t.textSecondary),
            title: const Text('Добавить в плейлист'),
            onTap: () {
              Navigator.pop(sheetCtx);
              showAddToPlaylistSheet(context, ref, track);
            },
          ),
          Consumer(builder: (_, r, __) {
            final liked = r.watch(libraryProvider).isLiked(track);
            return ListTile(
              leading: AppIcon(liked ? AppIcons.heartFilled : AppIcons.heart,
                  size: 20, color: liked ? t.danger : t.textSecondary),
              title: Text(liked ? 'Убрать из избранного' : 'В избранное'),
              onTap: () {
                r.read(libraryProvider).toggleLike(track);
                Navigator.pop(sheetCtx);
              },
            );
          }),
          Consumer(builder: (_, r, __) {
            final disliked = r.watch(recsStoreProvider).isDisliked(track);
            return ListTile(
              leading: AppIcon(
                  disliked ? AppIcons.thumbDown : AppIcons.thumbDown,
                  size: 20,
                  color: disliked ? t.warning : t.textSecondary),
              title: Text(disliked ? 'Убрать дизлайк' : 'Не нравится'),
              subtitle: disliked
                  ? null
                  : Text('Больше не показывать в рекомендациях',
                      style:
                          TextStyle(color: t.textTertiary, fontSize: t.micro.fontSize)),
              onTap: () {
                r.read(recsStoreProvider).toggleDislike(track);
                Navigator.pop(sheetCtx);
              },
            );
          }),
          if ((track.album ?? '').isNotEmpty)
            ListTile(
              leading:
                  AppIcon(AppIcons.library, size: 20, color: t.textSecondary),
              title: const Text('Открыть альбом'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlbumScreen(seed: track)));
              },
            ),
          ListTile(
            leading: AppIcon(AppIcons.share, size: 20, color: t.textSecondary),
            title: const Text('Поделиться карточкой'),
            onTap: () {
              Navigator.pop(sheetCtx);
              shareTrackCard(context, ref, track);
            },
          ),
          ListTile(
            leading: AppIcon(AppIcons.close, size: 22, color: t.textSecondary),
            title: Text('Скрыть артиста «${track.artist}»'),
            onTap: () {
              ref.read(libraryProvider).blacklistArtist(track.artist);
              Navigator.pop(sheetCtx);
              _snack(context, '«${track.artist}» скрыт из ленты и радио');
            },
          ),
        ],
      ),
    ),
  );
}

void _snack(BuildContext c, String m) {
  if (c.mounted) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  }
}