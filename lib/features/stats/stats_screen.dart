import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart';
import '../common/skin_controls.dart';
import '../common/skin_tokens.dart';
import '../common/track_row.dart';

/// Статистика: две вёрстки одного и того же набора чисел.
///
/// iOS показывает метрики плиткой 2×2 крупными числами — их четыре, и глаз
/// считывает «сетку» быстрее, чем строки. iPod показывает их же таблицей с
/// LCD-шрифтом и разделителями: на монохромном экране плитка без цвета
/// выглядит как четыре одинаковых серых прямоугольника, а строка «метка —
/// значение» читается как строка приборной панели.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    return Scaffold(
      backgroundColor: tokens.background,
      body: Column(
        children: [
          // Своя «шапка» вместо AppBar: экран открывается маршрутом и должен
          // выглядеть так же, как остальные, а Material-AppBar притащил бы тему,
          // ради которой всё затевалось.
          SizedBox(
            height: 56,
            child: Row(
              children: [
                SkinIconButton(
                  icon: AppIcons.back,
                  tooltip: 'Назад',
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Text(
                    'Статистика',
                    style: tokens.title.copyWith(color: tokens.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: StatsContent()),
        ],
      ),
    );
  }
}

/// Содержимое без «шапки» — чтобы оболочка скина (у которой своя панель
/// разделов) могла встроить его без второй шапки.
class StatsContent extends ConsumerWidget {
  const StatsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final lib = ref.watch(libraryProvider);
    final tracks = lib.topTracks(limit: 30);
    final artists = lib.topArtists(limit: 12);

    if (tracks.isEmpty && lib.totalListened == Duration.zero) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.stats,
        title: 'Пока нет прослушиваний',
        subtitle: 'Слушайте музыку — здесь появятся цифры и ваш топ.',
      );
    }

    final queue = tracks.map((e) => e.key).toList();
    return ListView(
      padding: EdgeInsets.only(bottom: tokens.space24),
      children: [
        id.isIpod
            ? _IpodMetrics(
                tokens: tokens,
                rows: [
                  ('Всего прослушано', fmtDuration(lib.totalListened)),
                  ('Прослушиваний', '${lib.totalPlays}'),
                  ('Уникальных треков', '${lib.uniqueTracks}'),
                  ('Артистов', '${lib.uniqueArtists}'),
                ],
              )
            : _IosMetrics(
                tokens: tokens,
                items: [
                  ('Всего прослушано', fmtDuration(lib.totalListened)),
                  ('Прослушиваний', '${lib.totalPlays}'),
                  ('Уникальных треков', '${lib.uniqueTracks}'),
                  ('Артистов', '${lib.uniqueArtists}'),
                ],
              ),
        if (artists.isNotEmpty) ...[
          SectionHeader(tokens: tokens, title: 'Топ артистов'),
          for (var i = 0; i < artists.length; i++)
            SkinMenuRow(
              // Номер в подписи, а не отдельной колонкой: в iPod-меню колонки
              // нет, а «1. …» одинаково читается в обеих темах.
              title: '${i + 1}. ${artists[i].key}',
              trailing: Text(
                '${artists[i].value}',
                style: tokens.caption.copyWith(color: tokens.accent),
              ),
            ),
        ],
        SectionHeader(tokens: tokens, title: 'Топ треков'),
        for (var i = 0; i < tracks.length; i++)
          SkinMenuRow(
            title: '${i + 1}. ${tracks[i].key.title}',
            subtitle: tracks[i].key.artist,
            onTap: () => playTrack(ref, context, tracks[i].key, queue: queue),
            trailing: Text(
              '${tracks[i].value}',
              style: tokens.caption.copyWith(color: tokens.accent),
            ),
          ),
      ],
    );
  }
}

/// Метрики iOS: сетка 2×2 крупными числами.
class _IosMetrics extends StatelessWidget {
  const _IosMetrics({required this.tokens, required this.items});

  final DesignTokens tokens;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space16,
        tokens.space16,
        tokens.space4,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: tokens.space12,
        crossAxisSpacing: tokens.space12,
        childAspectRatio: 2.1,
        children: [
          for (final (label, value) in items)
            Container(
              padding: EdgeInsets.all(tokens.space12),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusLg),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.micro.copyWith(color: tokens.textTertiary),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.title.copyWith(color: tokens.textPrimary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Метрики iPod: строки «метка — значение» монохромным LCD-шрифтом.
class _IpodMetrics extends StatelessWidget {
  const _IpodMetrics({required this.tokens, required this.rows});

  final DesignTokens tokens;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (label, value) in rows)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space16,
              vertical: tokens.space12,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.separator),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                ),
                SizedBox(width: tokens.space12),
                Text(
                  value,
                  style: tokens.headline.copyWith(color: tokens.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Длительность в «человеческих» единицах: д/ч/мин/сек.
String fmtDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  if (days > 0) return '$days д $hours ч';
  if (d.inHours > 0) return '${d.inHours} ч $mins мин';
  if (d.inMinutes > 0) return '$mins мин';
  return '${d.inSeconds} сек';
}
