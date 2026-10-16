import 'package:flutter/material.dart';

import '../../core/widgets/artwork.dart';
import '../../core/widgets/service_badge.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../domain/models/source_type.dart' show SourceTypeX;
import '../../domain/models/track.dart';

/// Ряд обложек главной в двух видах.
///
/// iOS показывает треки плитками в горизонтальный ряд, iPod — строками в
/// список. Оба элемента живут здесь, потому что это один и тот же смысл
/// («вот треки, поставь первый»), и различаются они только раскладкой.

/// Ширина обложки в горизонтальном ряду iOS.
///
/// 160 px — размер, при котором на типовом телефоне в ряд влезает три-четыре
/// обложки, а под названием трека остаётся строка без «…».
const double homeCoverWidth = 160;

/// Высота горизонтального ряда: квадратная обложка плюс две строки подписей и
/// воздух. Считается константой, а не через токены, потому что это размер
/// воркспейса конкретной раскладки, а не элемент палитры или типографики.
const double homeCoverRowHeight = 214;

/// Отступ между обложкой и подписями: без него подпись липла к следующей
/// обложке и ряд читался как полоса из картинок с текстом.
const double _captionGap = 8;

/// Плитка трека для iOS: обложка и две подписи.
///
/// Свой виджет, а не переиспользованный `TrackCard` из core: тот завязан на
/// Material-тему и AppColors, а главная после редизайна обязана брать цвет и
/// радиус из токенов скина.
class HomeTrackTile extends StatelessWidget {
  const HomeTrackTile({
    super.key,
    required this.tokens,
    required this.track,
    required this.onTap,
    this.width = homeCoverWidth,
  });

  final DesignTokens tokens;
  final Track track;
  final VoidCallback onTap;

  /// null — «во всю ширину» (для сетки в две колонки).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return SizedBox(
      width: width,
      child: Material(
        // Прозрачная подложка: плитка в ряду не должна выглядеть карточкой,
        // иначе ряд из двадцати одинаковых прямоугольников превращается в
        // простыню. Пятно нажатия всё равно даёт InkWell.
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Artwork(
                      t.artworkUrl,
                      seed: t.uid,
                      radius: tokens.radiusMd,
                    ),
                  ),
                  // Бейдж источника: на iOS это единственное цветное пятно на
                  // обложке, и по нему видно, откуда взялся трек.
                  Positioned(
                    left: tokens.space8,
                    bottom: tokens.space8,
                    child: ServiceBadge(t.source, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: _captionGap),
              Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.caption.copyWith(color: tokens.textPrimary),
              ),
              Text(
                t.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.micro.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Горизонтальный ряд обложек (iOS).
///
/// Ряд скроллится сам, поэтому у него своя ось: без этого жест по горизонтали
/// «срывал» бы страницу вбок.
class HomeCoverRow extends StatelessWidget {
  const HomeCoverRow({
    super.key,
    required this.tokens,
    required this.tracks,
    required this.onTap,
  });

  final DesignTokens tokens;
  final List<Track> tracks;

  /// Ставит в очередь весь ряд, а не один трек: иначе «продолжить» остановится
  /// на втором треке, хотя справа видно, что дальше есть что слушать.
  final void Function(Track track, List<Track> queue) onTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: homeCoverRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tokens.space16),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => SizedBox(width: tokens.space12),
        itemBuilder: (_, i) => HomeTrackTile(
          tokens: tokens,
          track: tracks[i],
          onTap: () => onTap(tracks[i], tracks),
        ),
      ),
    );
  }
}

/// Строка трека для меню iPod.
///
/// Источник здесь подписан словом, а не бейджем: монохромный экран не должен
/// получать цветные пятна, а «откуда трек» на iPod читается словами.
class HomeTrackRow extends StatelessWidget {
  const HomeTrackRow({
    super.key,
    required this.tokens,
    required this.track,
    required this.onTap,
    required this.coverSize,
  });

  final DesignTokens tokens;
  final Track track;
  final VoidCallback onTap;

  /// Сторона обложки. Задаёт вызывающий: в контракте [DesignTokens] размеров
  /// обложки нет, и у каждого скина он свой.
  final double coverSize;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: tokens.space24),
          padding: EdgeInsets.symmetric(vertical: tokens.space4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.separator, width: 1),
            ),
          ),
          child: Row(
            children: [
              Artwork(
                t.artworkUrl,
                size: coverSize,
                seed: t.uid,
                radius: tokens.radiusSm,
              ),
              SizedBox(width: tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.body.copyWith(color: tokens.textPrimary),
                    ),
                    Text(
                      t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          tokens.caption.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space8),
              Text(
                t.source.shortLabel,
                style: tokens.micro.copyWith(color: tokens.textTertiary),
              ),
              SizedBox(width: tokens.space4),
              AppIcon(
                AppIcons.chevronRight,
                size: 18,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
