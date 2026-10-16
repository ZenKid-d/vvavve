import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/album_menu.dart';
import '../../core/widgets/artwork.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/source_type.dart';
import '../album/album_screen.dart';
import 'skin_tokens.dart';
import 'track_card_tile.dart' show SourceTag;
import 'track_row.dart' show SkinRowSeparator;

/// Плитка альбома в двух темах.
///
/// Формы разные не из вкуса, а из плотности: iOS показывает альбомы сеткой
/// плиток (обложка + подпись под ней), потому что альбомов много и важно видеть
/// их сразу; iPod-меню альбомы показывало **списком** — одна строка, один
/// экран, никакой прокрутки вбок. Раньше один и тот же экран рисовал сетку в
/// обеих темах, и на монохромном экране это выглядело как чужое приложение.
///
/// [size] действует только в iOS-варианте (сторона обложки). В строке обложка
/// всегда [SkinIdMetrics.coverSize] — иначе строка перестаёт быть строкой.
class SkinAlbumTile extends StatelessWidget {
  const SkinAlbumTile({
    super.key,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.seed,
    this.source,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.size = 120,
    this.compact = false,
  });

  final String title;
  final String artist;
  final String? artworkUrl;
  final String? seed;

  /// Источник для бейджа; null — альбом без источника (свой плейлист).
  final SourceType? source;

  /// Третья строка подписи — обычно «N треков» или дата.
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Сторона обложки iOS-карточки.
  final double size;

  /// Рисовать строкой даже в iOS-скине: в вертикальном списке плейлистов
  /// плитка во всю ширину съедала бы по 160 px на позицию.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    return (id.isIpod || compact)
        ? _row(context, tokens, ipod: id.isIpod)
        : _card(tokens);
  }

  Widget _card(DesignTokens tokens) => SizedBox(
        width: size,
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Artwork(
                      artworkUrl,
                      size: size,
                      seed: seed,
                      radius: tokens.radiusMd,
                    ),
                    if (source != null)
                      Positioned(
                        left: tokens.space4,
                        bottom: tokens.space4,
                        child: SourceTag(source!),
                      ),
                  ],
                ),
                SizedBox(height: tokens.space4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.caption.copyWith(color: tokens.textPrimary),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.micro.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _row(BuildContext context, DesignTokens tokens, {required bool ipod}) {
    final id = skinOf(context).id;
    final subtitle = this.subtitle;
    // Строка всегда той же высоты, что и обложка скина, иначе позиции в
    // списке «прыгали» бы при переключении скина.
    final height = rowHeightFor(id);
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space8),
            child: Row(
              children: [
                Artwork(
                  artworkUrl,
                  size: id.coverSize,
                  seed: seed,
                  radius: ipod ? tokens.radiusSm : tokens.radiusMd,
                ),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (ipod ? tokens.headline : tokens.body)
                            .copyWith(color: tokens.textPrimary),
                      ),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (ipod ? tokens.micro : tokens.caption)
                            .copyWith(color: tokens.textSecondary),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (ipod ? tokens.micro : tokens.caption)
                              .copyWith(color: tokens.textTertiary),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Секция альбомов: лентой в iOS-скине и списком в iPod.
///
/// Форма выбирается по скину, а не по флагу: горизонтальная лента — это
/// прокрутка вбок, которой на корпусе iPod не было, и альбомы там читались
/// списком. Раскладка одна на оба скина.
class AlbumStrip extends ConsumerWidget {
  const AlbumStrip({super.key, required this.albums, required this.header});

  final List<AlbumResult> albums;

  /// Подпись секции («Альбомы»).
  final String header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    if (id.isIpod) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tokens: tokens, title: header),
          for (final a in albums) _tile(context, ref, a),
        ],
      );
    }
    // Высота ленты = сторона обложки + две строки подписи и отступы: считаем
    // по кеглям токенов, иначе подпись обрезается и выглядит как баг.
    const cover = 120.0;
    final stripHeight = cover +
        tokens.space4 * 2 +
        tokens.caption.fontSize! +
        tokens.micro.fontSize!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tokens: tokens, title: header),
        SizedBox(
          height: stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: tokens.space16),
            itemCount: albums.length,
            separatorBuilder: (_, __) => SizedBox(width: tokens.space12),
            itemBuilder: (_, i) => _tile(context, ref, albums[i]),
          ),
        ),
        const SkinRowSeparator(),
      ],
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AlbumResult a) =>
      SkinAlbumTile(
        title: a.title,
        artist: a.artist,
        artworkUrl: a.artworkUrl,
        seed: a.uid,
        source: a.source,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlbumScreen(seed: a.toSeedTrack()),
        )),
        onLongPress: () => showAlbumMenu(context, ref, a),
      );
}
