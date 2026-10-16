import 'package:flutter/material.dart';

import '../../design/tokens/design_tokens.dart';
import 'skin_tokens.dart';

/// Переключатель вкладок внутри экрана в двух темах.
///
/// iOS — привычная «полоса вкладок»: подпись активной вкладки акцентом и
/// короткое подчёркивание под ней, как в системных приложениях. iPod —
/// сегменты в общей рамке, где активный сегмент **инвертирован**: на
/// одноцветном экране выделение цветом невозможно, и настоящий iPod решал
/// это обратным тоном. Разные конструкции, а не одна с перекраской.
///
/// Экраны не должны рисовать переключатель сами: «как выглядит вкладка» —
/// свойство скина, иначе медиатека и поиск разъедутся.
class SectionTabBar extends StatelessWidget {
  const SectionTabBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.scrollable = true,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// Прокручивать ли ряд, если подписи не влезли. iPod-сегменты всегда
  /// делят ширину поровну: корпус iPod не умеет горизонтальную прокрутку, и
  /// скрытый сегмент означал бы «вкладку, которую нельзя открыть».
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    return id.isIpod ? _ipod(tokens) : _ios(tokens, scrollable: scrollable);
  }

  Widget _ios(DesignTokens tokens, {required bool scrollable}) {
    final tabs = <Widget>[
      for (var i = 0; i < labels.length; i++)
        _IosTab(
          tokens: tokens,
          label: labels[i],
          selected: i == index,
          onTap: () => onChanged(i),
        ),
    ];
    if (!scrollable) {
      return SizedBox(
        height: _height,
        child: Row(children: [for (final t in tabs) Expanded(child: t)]),
      );
    }
    return SizedBox(
      height: _height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: tabs,
      ),
    );
  }

  Widget _ipod(DesignTokens tokens) => Container(
        height: _segmentHeight,
        decoration: BoxDecoration(
          border: Border.all(color: tokens.separator),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) Container(width: 1, color: tokens.separator),
              Expanded(
                child: _IpodSegment(
                  tokens: tokens,
                  label: labels[i],
                  selected: i == index,
                  onTap: () => onChanged(i),
                ),
              ),
            ],
          ],
        ),
      );

  static const double _height = 36;
  static const double _segmentHeight = 32;
}

/// Вкладка iOS: подпись + подчёркивание активной.
class _IosTab extends StatelessWidget {
  const _IosTab({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.accent : tokens.textSecondary;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        // Ripple в iOS-скине должен быть мягким и круглым, а не заливать всю
        // вкладку: активную подсвечивает акцент, а не вспышка под пальцем.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space12),
          // IntrinsicWidth нужен только ради подчёркивания: оно должно быть
          // шириной подписи, а в горизонтальном списке ширина не ограничена
          // и `double.infinity` там означал бы «бесконечный» бокс.
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.body.copyWith(color: color),
                ),
                SizedBox(height: tokens.space4),
                Container(
                  height: 2,
                  width: selected ? double.infinity : 0,
                  color: tokens.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сегмент iPod: рамка общего блока + инвертированный активный.
class _IpodSegment extends StatelessWidget {
  const _IpodSegment({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? tokens.accentOn : tokens.textPrimary;
    return Material(
      color: selected ? tokens.accent : const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Трекинг micro-кегля — «пиксельный» шрифт меню iPod.
              style: tokens.micro.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
