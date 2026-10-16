import 'package:flutter/material.dart';

import '../../design/icons/app_icons.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/skin.dart';

/// «Моя волна» — главный элемент главной в двух видах.
///
/// Вид выбирается по скину, а не флагом: экран-вызывающий не должен знать, в
/// каком оформлении он живёт. Разница не косметическая — в iOS это первый
/// экран, в который палец тянется машинально, а в меню iPod это строчка в
/// списке, где всё остальное — соседние пункты.
class WaveCard extends StatelessWidget {
  const WaveCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (SkinScope.of(context).id) {
      SkinId.ipod => _IpodWaveRow(onTap: onTap),
      SkinId.ios => _IosWaveCard(onTap: onTap),
    };
  }
}

/// Высота карточки «Моя волна» в iOS.
///
/// Токены высоту карточек не держат (это не часть типографики или палитры), а
/// значение задано дизайном главной: 88 px — блок, который читается как
/// «большая кнопка» и в который попадает палец, не целясь.
const double waveCardHeight = 88;

/// Круг иконки внутри карточки. Меньше — не читается как точка входа,
/// больше — карточка перестаёт помещать в себя заголовок и подпись.
const double waveBadgeSize = 48;

/// Подпись под заголовком карточки: обещание, а не описание механики.
const String waveCardSubtitle = 'Живой поток — адаптируется под тебя';

/// Подпись строки в iPod. Короче: в меню iPod длинные подписи ломают
/// «экран в одну колонку подписей».
const String waveRowSubtitle = 'Живой поток';

/// Подпись самой точки входа.
const String waveTitle = 'Моя волна';

class _IosWaveCard extends StatelessWidget {
  const _IosWaveCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    // Подложка — сам акцент: на плотном тёмном фоне единственное цветное
    // пятно читается как действие, а не как украшение.
    final fg = t.accentOn;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space16, t.space12, t.space16, t.space8),
      child: Material(
        color: t.accent,
        borderRadius: BorderRadius.circular(t.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: waveCardHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space16),
              child: Row(
                children: [
                  _Badge(background: fg, foreground: t.accent),
                  SizedBox(width: t.space16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waveTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.headline
                              .copyWith(color: fg, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: t.space2),
                        Text(
                          waveCardSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                              color: fg.withValues(alpha: fg.a * 0.75)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.space8),
                  AppIcon(AppIcons.play, size: 26, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглая иконка в карточке: инвертированная относительно подложки.
///
/// Инверсия, а не «белый круг с белой иконкой» — иначе круг на iOS (синий
/// акцент, белый текст) и на iPod (белый акцент, тёмный текст) выглядели бы
/// двумя разными элементами.
class _Badge extends StatelessWidget {
  const _Badge({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: waveBadgeSize,
      height: waveBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: AppIcon(AppIcons.radio, size: 22, color: foreground),
    );
  }
}

/// «Моя волна» в меню iPod — обычная строка, а не выделенный блок.
///
/// Ровно потому, что это меню: всё остальное здесь — соседние пункты, и
/// выделение одного из них сбивало бы с толку, что он «главнее» соседей по
/// смыслу, хотя он просто чаще нажимается.
class _IpodWaveRow extends StatelessWidget {
  const _IpodWaveRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return IpodListRow(
      tokens: t,
      title: waveTitle,
      subtitle: waveRowSubtitle,
      leading: AppIcons.radio,
      onTap: onTap,
    );
  }
}
