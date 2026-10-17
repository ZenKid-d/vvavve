import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../design/icons/app_icons.dart';
import '../../design/widgets/blocks.dart';
import '../common/skin_tokens.dart';
import '../common/track_row.dart';

/// Чёрный список артистов: их треки не попадают в ленту, рекомендации и радио.
class BlacklistScreen extends ConsumerWidget {
  const BlacklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = skinOf(context).tokens;
    final artists = ref.watch(libraryProvider).blacklistedArtists;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title: Text('Чёрный список артистов',
            style: t.headline.copyWith(color: t.textPrimary)),
      ),
      body: artists.isEmpty
          ? EmptyState(
              // Пустое состояние — общий блок скинов: своя верстка здесь
              // лишь дублировала бы EmptyState и разъезжалась между темами.
              tokens: t,
              icon: AppIcons.delete,
              title: 'Пусто',
              subtitle: 'Чтобы скрыть артиста — долгий тап на его треке → '
                  '«Скрыть артиста».')
          : ListView(
              children: [
                for (final a in artists)
                  SkinMenuRow(
                    title: a,
                    leading: AppIcons.delete,
                    trailing: IconButton(
                      icon: AppIcon(AppIcons.close,
                          size: 20, color: t.textSecondary),
                      tooltip: 'Вернуть артиста',
                      onPressed: () =>
                          ref.read(libraryProvider).unblacklistArtist(a),
                    ),
                  ),
              ],
            ),
    );
  }
}
