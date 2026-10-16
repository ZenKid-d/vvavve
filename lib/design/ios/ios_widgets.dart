import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../skin.dart';
import '../tokens/design_tokens.dart';

export '../widgets/blocks.dart'
    show EmptyState, ErrorBlock, LoadingBlock, SectionHeader, SkinCanvas;

/// Строка списка iOS-скина.
///
/// Высота жёстко зафиксирована (44 px — стандартная строка iOS, попадать
/// пальцем ниже нельзя), скругление — радиус токена, чтобы на iOS с его
/// крупными радиусами строка читалась «карточкой», а не полосой.
class IosListRow extends StatelessWidget {
  const IosListRow({
    super.key,
    required this.tokens,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.background,
  });

  final DesignTokens tokens;
  final AppIconData? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Material(
      color: background ?? tokens.surface,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space12,
              vertical: tokens.space8,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  AppIcon(leading!, size: 22, color: tokens.accent),
                  SizedBox(width: tokens.space12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.body.copyWith(color: tokens.textPrimary),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.caption
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
      ),
    );
  }
}

/// Нижняя панель разделов iOS: подпись + иконка, активный — акцентом.
class IosTabBar extends StatelessWidget {
  const IosTabBar({
    super.key,
    required this.tokens,
    required this.sections,
    required this.currentIndex,
    required this.onSection,
    this.height = 52,
  });

  final DesignTokens tokens;
  final List<SkinSection> sections;
  final int currentIndex;
  final ValueChanged<int> onSection;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.separator)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < sections.length; i++)
                  Expanded(
                    child: _TabItem(
                      tokens: tokens,
                      section: sections[i],
                      selected: i == currentIndex,
                      onTap: () => onSection(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Пункт панели вынесен отдельно, чтобы не раздувать [IosTabBar].
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tokens,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final DesignTokens tokens;
  final SkinSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.accent : tokens.textTertiary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(section.icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            section.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.micro.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}