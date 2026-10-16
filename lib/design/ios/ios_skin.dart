import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../skin.dart';
import '../tokens/design_tokens.dart';
import '../tokens/ios_tokens.dart';
import 'ios_widgets.dart';

/// Скин iOS: плотный тёмный интерфейс с нижней панелью разделов.
///
/// Экраны здесь — заглушки. Реальные реализации напишут другие агенты,
/// подключив контроллеры; скин уже собран так, чтобы подмена экрана была
/// правкой одного метода и не трогала оболочку.
///
/// `extends`, а не `implements`: интерфейс [Skin] умеет сам строить раздел по
/// индексу, и переписывать это в каждом скине незачем.
class IosSkin extends Skin {
  @override
  SkinId get id => SkinId.ios;

  @override
  DesignTokens get tokens => IosTokens.instance;

  @override
  Widget buildShell(
    BuildContext context,
    Widget body, {
    required int sectionIndex,
    required ValueChanged<int> onSection,
    required VoidCallback onSettings,
  }) {
    return Scaffold(
      backgroundColor: tokens.background,
      body: body,
      bottomNavigationBar: IosTabBar(
        tokens: tokens,
        sections: SkinSection.values,
        currentIndex: sectionIndex,
        onSection: onSection,
      ),
    );
  }

  @override
  Widget buildHome(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Главная');

  @override
  Widget buildSearch(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Поиск');

  @override
  Widget buildLibrary(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Медиатека');

  @override
  Widget buildStats(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Статистика');

  @override
  Widget buildSettings(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Настройки');

  @override
  Widget buildPlayer(BuildContext context) =>
      _Stub(tokens: tokens, label: 'iOS — Плеер');

  // TODO(iOS): заменить на реальные экраны. Заглушка должна быть последней
  // вещью, которую удаляют из скина.
}

/// Общий экран-заглушка: фон из токенов и подпись, по которой видно, какой
/// скин и какой экран отрисован.
class _Stub extends StatelessWidget {
  const _Stub({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SkinCanvas(
      tokens: tokens,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: tokens.headline.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            AppIcon(
              AppIcons.musicNote,
              size: 28,
              color: tokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}