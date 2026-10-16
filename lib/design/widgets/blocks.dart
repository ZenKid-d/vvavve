import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../tokens/design_tokens.dart';

/// Примитивы, одинаковые для обоих скинов.
///
/// Вынесены отдельно от `ios_widgets.dart`/`ipod_widgets.dart` намеренно:
/// заголовок секции или пустое состояние не имеют «iOS- или iPod-вида» — они
/// просто читают токены. Дублировать их в двух скинах значило бы через месяц
/// получить два расходящихся определения одного и того же блока.
///
/// Всё, что действительно выглядит по-разному (строка списка, меню, экран),
/// живёт в файле своего скина.

/// Заголовок секции. Трекинг и цвет — из токенов, чтобы заголовки в iPod не
/// оказались с тем же интерлиньяжем, что в iOS.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.tokens,
    required this.title,
    this.trailing,
  });

  final DesignTokens tokens;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space24,
        tokens.space16,
        tokens.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tokens.caption.copyWith(
                color: tokens.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Пустое состояние: иконка, заголовок и пояснение — одним блоком по центру.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final DesignTokens tokens;
  final AppIconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, color: tokens.textTertiary, size: 40),
            SizedBox(height: tokens.space12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tokens.headline.copyWith(color: tokens.textSecondary),
            ),
            SizedBox(height: tokens.space4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: tokens.caption.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Заглушка на время загрузки.
///
/// Не кольцо-спиннер: у скина своя плотность, и «крутилка» iOS на чёрном
/// iPod-экране смотрелась бы как чужой элемент. Три полоски-«дешифра» совпадают
/// с монохромной эстетикой обоих скинов и не требуют анимации.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, required this.tokens, this.lines = 3});

  final DesignTokens tokens;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.space4),
              child: Container(
                width: 120 + i * 40.0,
                height: 6,
                decoration: BoxDecoration(
                  color: tokens.separator,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ошибка с возможностью повторить. [onRetry] null — показываем только текст.
class ErrorBlock extends StatelessWidget {
  const ErrorBlock({
    super.key,
    required this.tokens,
    required this.message,
    required this.onRetry,
  });

  final DesignTokens tokens;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.warning,
              color: tokens.danger,
              size: 36,
            ),
            SizedBox(height: tokens.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tokens.body.copyWith(color: tokens.textSecondary),
            ),
            if (onRetry != null) ...[
              SizedBox(height: tokens.space16),
              // Кнопка-«капсуля» работает в обоих скинах: на iPod это
              // инвертированный блок, и он всё равно перекрывает собой фон.
              Material(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space16,
                      vertical: tokens.space8,
                    ),
                    child: Text(
                      'Повторить',
                      style: tokens.caption.copyWith(
                        color: tokens.accentOn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Фон экрана: цвет из токенов + необязательная текстура, если скин её ждёт.
class SkinCanvas extends StatelessWidget {
  const SkinCanvas({super.key, required this.tokens, required this.child});

  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final texture = tokens.backgroundTextureAsset;
    return ColoredBox(
      color: tokens.background,
      child: texture == null
          ? child
          : Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    texture,
                    fit: BoxFit.cover,
                    // Текстура — фон, а не содержание: её отсутствие (удалённый
                    // кэш, битый asset) не должно ронять экран.
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(child: child),
              ],
            ),
    );
  }
}