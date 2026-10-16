import 'package:flutter/material.dart';

import '../../core/widgets/artwork.dart';
import '../../design/tokens/design_tokens.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';
import 'skin_tokens.dart';

/// Вертикальная плитка трека в двух темах — для рядов на главной и в поиске.
///
/// iOS: обложка квадратом, под ней название и артист, поверх обложки — бейдж
/// источника (цветной, как в Music). iPod: та же геометрия, но монохромная —
/// без скруглений, без цветного бейджа и с «LCD»-подписями. Убирать обложку
/// у iPod нельзя: на одноцветном экране это единственное, что отличает один
/// трек от другого глазом.
class SkinTrackTile extends StatelessWidget {
  const SkinTrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.width,
  });

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Ширина плитки. null — по содержимому (обычно её задаёт ряд).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final ipod = id.isIpod;
    final size = width ?? (ipod ? 140.0 : 120.0);

    return SizedBox(
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
                    track.artworkUrl,
                    size: size,
                    seed: track.uid,
                    radius: tokens.radiusSm,
                  ),
                  if (!ipod)
                    Positioned(
                      left: tokens.space4,
                      bottom: tokens.space4,
                      child: SourceTag(track.source),
                    ),
                ],
              ),
              SizedBox(height: tokens.space4),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.caption.copyWith(color: tokens.textPrimary),
              ),
              SizedBox(height: ipod ? tokens.space2 : 0),
              Text(
                track.artist,
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

/// Бейдж источника на обложке.
///
/// Фиолетовый/красный цвет сервиса оправдан только в iOS-скине: он помогает
/// понять, откуда трек, ещё до чтения подписи. В монохромном iPod тот же
/// бейдж рисуется инвертированным блоком с подписью — иначе единственное
/// цветное пятно выбивалось бы из образа корпуса.
class SourceTag extends StatelessWidget {
  const SourceTag(this.source, {super.key});

  final SourceType source;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final ipod = id.isIpod;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ipod ? tokens.textPrimary : source.color,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space4,
          vertical: ipod ? tokens.space2 : tokens.space2,
        ),
        child: Text(
          source.shortLabel,
          style: _style(ipod, tokens),
        ),
      ),
    );
  }

  TextStyle _style(bool ipod, DesignTokens tokens) => tokens.micro.copyWith(
        color: ipod ? tokens.accentOn : source.onColor,
      );
}
