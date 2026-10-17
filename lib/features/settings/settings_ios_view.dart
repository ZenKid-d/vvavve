import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart' show Routes;
import '../../design/icons/app_icons.dart';
import 'about_screen.dart';
import 'settings_controller.dart' show SettingsCopy;
import 'settings_widgets.dart';

/// Настройки в iOS-скине: корневой список разделов и подэкраны к нему.
///
/// Классическая раскладка iOS — не одна простыня, а список пунктов, каждый из
/// которых ведёт на свой экран. Такое деление выбрано не «как в iOS», а по
/// смыслу: настроек больше тридцати, и в одной ленте пользователь не
/// находит нужное, а ещё и прокручивает мимо баннера на пол-экрана.
class SettingsIosView extends StatelessWidget {
  const SettingsIosView({super.key, required this.onOpen});

  /// Открыть подэкран. Внешний [settings_screen.dart] владеет состоянием и
  /// шапкой — здесь только список.
  final ValueChanged<SettingsSubPage> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const SettingsSection(title: 'vvavve'),
        SettingsActionRow(
          title: SettingsCopy.sources,
          subtitle: 'Яндекс, SoundCloud, VK, YouTube Music',
          leading: AppIcons.musicNote,
          onTap: () => onOpen(SettingsSubPage.sources),
        ),
        const SettingsGap(2),
        SettingsActionRow(
          title: 'Внешний вид',
          subtitle: 'Тема оформления',
          leading: AppIcons.sparkles,
          // Экран внешнего вида — общий с iPod и живёт отдельным маршрутом,
          // его переписывает агент плеера; подменять его здесь нельзя.
          onTap: () => context.push(Routes.appearance),
        ),
        const SettingsSection(title: SettingsCopy.audio),
        SettingsActionRow(
          title: 'Звук',
          subtitle: 'Кроссфейд, тишина, нормализация, качество',
          leading: AppIcons.volume,
          onTap: () => onOpen(SettingsSubPage.audio),
        ),
        const SettingsSection(title: SettingsCopy.network),
        SettingsActionRow(
          title: 'Сеть',
          subtitle: 'DoH, локальный прокси',
          leading: AppIcons.radio,
          onTap: () => onOpen(SettingsSubPage.network),
        ),
        const SettingsSection(title: 'Аккаунты'),
        SettingsActionRow(
          title: 'Аккаунты',
          subtitle: 'Google для синхронизации, Last.fm для скробблинга',
          leading: AppIcons.home,
          onTap: () => onOpen(SettingsSubPage.accounts),
        ),
        const SettingsSection(title: 'Данные'),
        SettingsActionRow(
          title: 'Данные',
          subtitle: 'Резервная копия, память, статистика',
          leading: AppIcons.storage,
          onTap: () => onOpen(SettingsSubPage.data),
        ),
        const SettingsSection(title: SettingsCopy.update),
        SettingsActionRow(
          title: SettingsCopy.update,
          subtitle: 'Проверка и установка новой версии',
          leading: AppIcons.download,
          onTap: () => onOpen(SettingsSubPage.update),
        ),
        const SettingsSection(title: 'О приложении'),
        SettingsActionRow(
          title: 'О приложении',
          subtitle: 'Версия, условия использования, лицензии',
          leading: AppIcons.warning,
          onTap: () => onOpen(SettingsSubPage.about),
        ),
      ],
    );
  }
}

/// Подэкран настроек iOS: шапка с «назад» и содержимое раздела.
class SettingsIosSubPage extends StatelessWidget {
  const SettingsIosSubPage({
    super.key,
    required this.page,
    required this.onBack,
  });

  final SettingsSubPage page;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (page == SettingsSubPage.about) return AboutScreen(onBack: onBack);

    return SettingsPage(
      title: settingsPageTitle(page),
      onBack: onBack,
      children: [
        for (final child in _children(page)) ...[child, const SettingsGap(4)],
      ],
    );
  }

  /// Содержимое раздела. Отступы между блоками добавляет вызывающий.
  static List<Widget> _children(SettingsSubPage page) => switch (page) {
        SettingsSubPage.sources => const [SettingsSourcesBlock()],
        SettingsSubPage.audio => const [SettingsAudioBlock()],
        SettingsSubPage.network => const [SettingsNetworkBlock()],
        SettingsSubPage.accounts => const [SettingsAccountsBlock()],
        SettingsSubPage.data => const [SettingsDataBlock()],
        SettingsSubPage.update => const [SettingsUpdateBlock()],
        SettingsSubPage.about => const [],
      };
}