import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../skin.dart';
import '../tokens/design_tokens.dart';
import '../tokens/ipod_tokens.dart';
import 'ipod_widgets.dart';

/// Скин iPod Classic: меню с бегущим заголовком, монохром, графитовый фон.
///
/// Оболочка принципиально другая: вместо нижней панели — «шапка» меню с
/// заголовком по центру и переключением разделов шевронами, потому что именно
/// так выглядел iPod. Именно здесь и видна разница между «скином» и «темой».
class IpodSkin extends Skin {
  @override
  SkinId get id => SkinId.ipod;

  @override
  DesignTokens get tokens => IpodTokens.instance;

  @override
  Widget buildShell(
    BuildContext context,
    Widget body, {
    required int sectionIndex,
    required ValueChanged<int> onSection,
    required VoidCallback onSettings,
  }) {
    // Заголовок едет по кругу: длинные названия на узком экране iPod —
    // норма, а не редкость.
    final title = SkinSection.values[sectionIndex].title;
    final canBack = sectionIndex > 0;
    final canForward = sectionIndex < SkinSection.values.length - 1;

    return Scaffold(
      backgroundColor: tokens.background,
      body: GraphiteBackground(
        base: tokens.background,
        child: Column(
          children: [
            IpodMenuBar(
              tokens: tokens,
              title: title,
              height: 44,
              onBack: canBack ? () => onSection(sectionIndex - 1) : null,
              onSettings: onSettings,
            ),
            // Двойной шеврон вправо вместо настроек — как «вперёд» на iPod.
            if (canForward)
              Padding(
                padding: EdgeInsets.only(top: tokens.space8, bottom: tokens.space4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    AppIcon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Выбрать',
                      style: tokens.micro.copyWith(color: tokens.textTertiary),
                    ),
                  ],
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildHome(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Главная');

  @override
  Widget buildSearch(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Поиск');

  @override
  Widget buildLibrary(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Медиатека');

  @override
  Widget buildStats(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Статистика');

  @override
  Widget buildSettings(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Настройки');

  @override
  Widget buildPlayer(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iPod — Плеер');

  // TODO(iPod): заменить на реальные экраны + scroll wheel навигацию.
}

/// Экран-заглушка iPod. Текст монохромный и центрированный — как надпись на
/// LCD в меню.
class _Stub extends StatelessWidget {
  const _Stub({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.musicNote, size: 32, color: tokens.textSecondary),
          SizedBox(height: tokens.space12),
          Text(
            label,
            style: tokens.headline.copyWith(color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}