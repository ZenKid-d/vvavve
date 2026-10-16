import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/track_menu.dart';
import '../../core/widgets/artwork.dart';
import '../../design/icons/app_icons.dart';
import '../../design/ios/ios_widgets.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../domain/models/track.dart';
import 'skin_tokens.dart';

/// Строка трека в двух темах — общая для медиатеки, поиска и статистики.
///
/// Раньше на каждый экран была своя строка на [ListTile], и «плотный iOS» и
/// «крупный монохромный iPod» отличались только цветом текста. Здесь
/// различие доведено до формы:
///
///  * **iOS** — обложка 44 px со скруглением токена, название и артист, а у
///    играющего трека ещё и вертикальная акцентная планка слева;
///  * **iPod** — обложка 64 px без скруглений, подписи «LCD» (крупный
///    трекинг), а играющий трек помечен треугольником ▶: на монохромном
///    экране цветом ничего не выразить, приходится формой.
///
/// Долгий тап открывает контекстное меню ([showTrackMenu]) — тот же жест, что
/// был до редизайна; [onLongPress] его переопределяет там, где жест занят
/// (перетаскивание в очереди).
class SkinTrackRow extends ConsumerWidget {
  const SkinTrackRow({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.active = false,
    this.showMenu = true,
  });

  final Track track;

  /// `null` — строка некликабельна.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// Трек сейчас играет.
  final bool active;

  /// Показывать ли контекстное меню по долгому тапу.
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final height = rowHeightFor(id);
    final ipod = id.isIpod;

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        onLongPress: _longPress(context, ref),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              // Акцентная планка iOS: полоса в 3 px читается как «играет»
              // мгновенно, не дожидаясь, пока глаз найдёт цвет текста.
              active && !ipod
                  ? Container(width: 3, color: tokens.accent)
                  : const SizedBox(width: 3),
              SizedBox(width: tokens.space8),
              // iPod: треугольник перед обложкой — единственный признак
              // «играет», который не зависит от палитры.
              if (active && ipod) ...[
                AppIcon(AppIcons.play, size: 12, color: tokens.textPrimary),
                SizedBox(width: tokens.space4),
              ],
              Artwork(
                track.artworkUrl,
                size: id.coverSize,
                seed: track.uid,
                radius: tokens.radiusSm,
              ),
              SizedBox(width: tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (ipod ? tokens.headline : tokens.body).copyWith(
                        color: active ? tokens.accent : tokens.textPrimary,
                      ),
                    ),
                    SizedBox(height: ipod ? tokens.space2 : 0),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (ipod ? tokens.micro : tokens.caption)
                          .copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.space8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _longPress(BuildContext context, WidgetRef ref) {
    if (onLongPress != null) return onLongPress;
    if (!showMenu) return null;
    return () => showTrackMenu(context, ref, track);
  }
}

/// Строка в форме «меню» (плейлист, пункт импорта, строка статистики).
///
/// Отдельная от [SkinTrackRow] сущность: у пункта меню нет обложки и нет
/// смысла в контекстном меню трека, зато есть шеврон «дальше». Внутри — те же
/// примитивы, что написаны для скинов, поэтому экран не дублирует их
/// разметку и не рисует «свой» iOS/iPod дважды.
class SkinMenuRow extends StatelessWidget {
  const SkinMenuRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final AppIconData? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Выбранный пункт — инвертированный блок (только iPod умеет так).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    return id.isIpod
        ? IpodListRow(
            tokens: tokens,
            title: title,
            leading: leading,
            subtitle: subtitle,
            trailing: trailing,
            onTap: onTap,
            selected: selected,
          )
        : IosListRow(
            tokens: tokens,
            title: title,
            leading: leading,
            subtitle: subtitle,
            trailing: trailing,
            onTap: onTap,
          );
  }
}

/// Разделитель-волосок между строками.
///
/// И iOS, и iPod рисуют список разделителями, а не «плашками»: в iOS-скине
/// плашка съела бы плотность (строка 44 px), а в iPod-скине плашек не было
/// вовсе — был список на чёрном фоне. Один примитив на оба скина.
class SkinRowSeparator extends StatelessWidget {
  const SkinRowSeparator({super.key, this.indent = 0});

  /// Отступ начала линии — обычно равен вылету обложки, чтобы текст не
  /// «липнул» к краю.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: tokens.separator),
    );
  }
}
