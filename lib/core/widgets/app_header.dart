import 'package:flutter/material.dart';

import '../../design/icons/app_icons.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/tokens/ipod_tokens.dart';

/// Шапка экрана в двух видах — по одному на каждый скин.
///
/// Это НЕ часть каркаса скина ([Skin.buildShell]): панель разделов и меню iPod
/// живут в скине, а шапка принадлежит конкретному экрану (настройки, альбом,
/// статистика), и каждый из них решает сам, нужна ли она. Оболочка собирает
/// шапку из этого виджета, а не рисует заголовок сама — иначе заголовки
/// разделов и заголовки поверх маршрутов разъехались бы по кеглям.
///
/// Вид выбирается по скину в контексте ([SkinScope]), поэтому вызывающему коду
/// не нужно знать, iOS перед ним или iPod. Вне скина (тест, превью) берётся
/// iOS-вид — он менее навязчивый.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.onForward,
  });

  final String title;

  /// Шестерёнка справа. null — кнопки нет (например, на самих настройках).
  final VoidCallback? onSettings;

  /// Кнопка слева: назад вглубь экрана.
  final VoidCallback? onBack;

  /// Шеврон «вперёд». Только iPod-вид: там это вторая половина пары шевронов.
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final skin = SkinScope.maybeOf(context) ?? skinFor(SkinId.ios);
    return skin.id == SkinId.ipod
        ? IpodAppHeader(
            title: title,
            onBack: onBack,
            onSettings: onSettings,
            onForward: onForward,
          )
        : IosAppHeader(
            title: title,
            onBack: onBack,
            onSettings: onSettings,
          );
  }
}

/// Шапка iOS: крупный заголовок раздела, слева — кнопка меню/назад, справа —
/// шестерёнка.
///
/// Заголовок берётся из [DesignTokens.display] — старшего кегля шкалы (34 в
/// iOS, 28 в iPod). Хардкодить «28» здесь нельзя: у скина своя шкала, и
/// число из другого скина сделало бы заголовок чужеродным.
class IosAppHeader extends StatelessWidget {
  const IosAppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.skin,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  /// Явно заданный скин. null — взять из [SkinScope].
  final Skin? skin;

  @override
  Widget build(BuildContext context) {
    final t = (skin ?? SkinScope.maybeOf(context) ?? skinFor(SkinId.ios)).tokens;
    return Container(
      color: t.background,
      padding: EdgeInsets.fromLTRB(t.space8, t.space8, t.space8, t.space4),
      child: Row(
        children: [
          _HeaderButton(
            icon: AppIcons.back,
            tooltip: 'Назад',
            onTap: onBack,
            color: t.accent,
            tokens: t,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.display.copyWith(color: t.textPrimary),
            ),
          ),
          _HeaderButton(
            icon: AppIcons.gear,
            tooltip: 'Настройки',
            onTap: onSettings,
            color: t.accent,
            tokens: t,
          ),
        ],
      ),
    );
  }
}

/// Шапка iPod: бегущий заголовок между шевронами, высота — из токенов.
///
/// Высота берётся из [IpodTokens.menuBarHeight] напрямую, а не через
/// [DesignTokens]: контракт токенов общий для двух скинов, и «высота шапки
/// меню» — понятие только iPod. Тащить её в общий контракт ради одного
/// значения означало бы заставить iOS отвечать на вопрос, который к нему не
/// относится.
class IpodAppHeader extends StatelessWidget {
  const IpodAppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.onForward,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ipod).tokens;
    return Container(
      height: IpodTokens.menuBarHeight,
      decoration: BoxDecoration(
        color: t.background,
        border: Border(bottom: BorderSide(color: t.separator)),
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: AppIcons.back,
            onTap: onBack,
            color: t.textSecondary,
            tokens: t,
          ),
          // Бегущая строка: на узком экране iPod длинное название — норма,
          // а многоточие здесь читалось бы как обрыв данных.
          Expanded(
            child: MarqueeTitle(
              tokens: t,
              text: title,
              style: t.headline.copyWith(color: t.textPrimary),
            ),
          ),
          _HeaderButton(
            icon: AppIcons.chevronRight,
            tooltip: 'Вперёд',
            onTap: onForward,
            color: t.textSecondary,
            tokens: t,
          ),
          _HeaderButton(
            icon: AppIcons.gear,
            tooltip: 'Настройки',
            onTap: onSettings,
            color: t.textSecondary,
            tokens: t,
          ),
        ],
      ),
    );
  }
}

/// Кнопка шапки.
///
/// Размер зоны тапа — 44 px в обоих скинах: это минимум, который вообще можно
/// попасть пальцем, и он не зависит от плотности списка, поэтому его можно
/// держать константой. Иконка, цвет и форма — из токенов и набора AppIcons.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tokens,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  /// Минимальная зона касания. Не токен: палец не знает, какой скин нарисован.
  static const double _tap = 44;

  final AppIconData icon;
  final DesignTokens tokens;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Без обработчика кнопки нет вовсе, а не «серая» — на iPod серый значок
    // читался бы как недоступное действие.
    if (onTap == null) return const SizedBox(width: _tap, height: _tap);
    final button = SizedBox(
      width: _tap,
      height: _tap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: AppIcon(icon, size: 22, color: color)),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}

/// Крупный заголовок для [CustomScrollView]: в iOS он уезжает в строку при
/// прокрутке, в iPod остаётся шапкой меню.
///
/// Отдельный виджет, а не [AppHeader], потому что sliver живёт в списке
/// скролла, а шапка — над ним: положить одно в другое нельзя.
class AppLargeTitleHeader extends StatelessWidget {
  const AppLargeTitleHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.topPadding,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  /// Высота статус-бара. Экран обязан передать [MediaQuery.paddingOf].top
  /// (или обернуть скролл в SafeArea) — sliver сам про MediaQuery не знает,
  /// а заголовок, уехавший под чёлку, выглядит как обрезанный.
  final double? topPadding;

  @override
  Widget build(BuildContext context) {
    final skin = SkinScope.maybeOf(context) ?? skinFor(SkinId.ios);
    final top = topPadding ?? MediaQuery.paddingOf(context).top;
    if (skin.id == SkinId.ipod) {
      return SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedMenuBarDelegate(
          title: title,
          onBack: onBack,
          onSettings: onSettings,
          skin: skin,
          topPadding: top,
        ),
      );
    }
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleDelegate(
        title: title,
        onBack: onBack,
        onSettings: onSettings,
        skin: skin,
        topPadding: top,
      ),
    );
  }
}

/// Заголовок iOS, уменьшающийся при прокрутке: от [DesignTokens.display] до
/// [DesignTokens.headline], из одной шкалы того же скина.
class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  const _LargeTitleDelegate({
    required this.title,
    required this.skin,
    required this.onBack,
    required this.onSettings,
    required this.topPadding,
  });

  final String title;
  final Skin skin;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final double topPadding;

  /// Свёрнутое состояние — строка iOS, плюс место под статус-бар.
  static const double _collapsed = 44;

  /// Развёрнутое состояние: крупный заголовок + строка кнопок.
  static const double _expanded = 104;

  @override
  double get minExtent => _collapsed + topPadding;

  @override
  double get maxExtent => _expanded + topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = skin.tokens;
    const span = _expanded - _collapsed;
    // Плавность задаёт сам скролл (shrinkOffset), поэтому интерполяция
    // линейная: кривая здесь только добавила бы отставание от пальца.
    final k = span <= 0 ? 1.0 : (1 - shrinkOffset / span).clamp(0.0, 1.0);
    final style = TextStyle.lerp(t.headline, t.display, k)!.copyWith(
      color: t.textPrimary,
    );
    return Container(
      color: t.background,
      padding: EdgeInsets.symmetric(horizontal: t.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPadding),
          SizedBox(
            height: _collapsed,
            child: Row(
              children: [
                _HeaderButton(
                  icon: AppIcons.back,
                  tooltip: 'Назад',
                  onTap: onBack,
                  color: t.accent,
                  tokens: t,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
                _HeaderButton(
                  icon: AppIcons.gear,
                  tooltip: 'Настройки',
                  onTap: onSettings,
                  color: t.accent,
                  tokens: t,
                ),
              ],
            ),
          ),
          // Крупный заголовок живёт под строкой кнопок и уезжает вместе с ней.
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Opacity(
                opacity: k,
                child: Padding(
                  padding: EdgeInsets.only(left: t.space4, bottom: t.space4),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.display.copyWith(color: t.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.title != title ||
      old.skin.id != skin.id ||
      old.onBack != onBack ||
      old.onSettings != onSettings ||
      old.topPadding != topPadding;
}

/// Заголовок строки iPod: та же высота, что и у меню, без анимации — на iPod
/// заголовок никогда не уезжает.
class _PinnedMenuBarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedMenuBarDelegate({
    required this.title,
    required this.skin,
    required this.onBack,
    required this.onSettings,
    required this.topPadding,
  });

  final String title;
  final Skin skin;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final double topPadding;

  @override
  double get minExtent => IpodTokens.menuBarHeight + topPadding;

  @override
  double get maxExtent => IpodTokens.menuBarHeight + topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: IpodAppHeader(
        title: title,
        onBack: onBack,
        onSettings: onSettings,
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedMenuBarDelegate old) =>
      old.title != title ||
      old.skin.id != skin.id ||
      old.onBack != onBack ||
      old.onSettings != onSettings ||
      old.topPadding != topPadding;
}