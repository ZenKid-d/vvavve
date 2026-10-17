import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/artwork.dart';
import '../../data/recs/recs_store.dart';
import '../../design/icons/app_icons.dart';
import '../../design/widgets/blocks.dart';
import '../../domain/models/track.dart';
import '../common/skin_controls.dart';
import '../common/skin_tokens.dart';

/// Экран дизлайков: треки, исключённые из рекомендаций. Дизлайк можно снять.
class DislikesScreen extends ConsumerWidget {
  const DislikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = skinOf(context).tokens;
    final store = ref.watch(recsStoreProvider);
    final items = store.dislikedTracks;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title:
            Text('Дизлайки', style: t.headline.copyWith(color: t.textPrimary)),
      ),
      body: items.isEmpty
          ? EmptyState(
              // Дизлайк — тот же глиф, что и на плеере: «отвергнутое» узнаётся
              // без чтения заголовка, в любой из тем.
              tokens: t,
              icon: AppIcons.thumbDown,
              title: 'Пусто',
              subtitle: 'Дизлайкнутые треки не попадают в рекомендации.\n'
                  'Дизлайк — на плеере или в меню трека.')
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) =>
                  _DislikeRow(store: store, track: items[i]),
            ),
    );
  }
}

/// Строка дизлайка: обложка, подписи и кнопка «вернуть».
///
/// Свой ряд на токенах, а не ListTile: ведущий элемент — обложка, а не иконка,
/// и плитка Material в iPod выбивалась бы из монохромного списка.
class _DislikeRow extends StatelessWidget {
  const _DislikeRow({required this.store, required this.track});

  final RecsStore store;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space16, vertical: t.space8),
      child: Row(
        children: [
          Artwork(track.artworkUrl, size: 44, seed: track.uid,
              radius: t.radiusMd),
          SizedBox(width: t.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: t.textPrimary)),
                SizedBox(height: t.space2),
                Text(track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          // «Вернуть» — sync-глиф (две дуги со стрелками): undo-иконка из
          // Material Icons в скин-слое запрещена, штатного undo у AppIcons нет.
          SkinIconButton(
            icon: AppIcons.sync,
            tooltip: 'Вернуть в рекомендации',
            color: t.textSecondary,
            onPressed: () => store.undislikeKey(RecsStore.keyFor(track)),
          ),
        ],
      ),
    );
  }
}
