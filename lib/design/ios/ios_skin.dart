import 'package:flutter/material.dart';

import '../skin.dart';
import '../tokens/design_tokens.dart';
import '../tokens/ios_tokens.dart';
import 'ios_widgets.dart';

/// Скин iOS: плотный тёмный интерфейс с нижней панелью разделов.
///
/// Скин отвечает только за каркас: какой раздел переключает нижняя панель
/// и как она выглядит. Контент каждого раздела — тонкий экран
/// (`features/home/home_screen.dart` и соседи), который читает токены
/// через [SkinScope]; поэтому третий скин не трогает ни оболочку, ни экраны.
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
}