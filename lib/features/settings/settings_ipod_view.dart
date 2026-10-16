import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart' show Routes;
import '../../design/icons/app_icons.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/tokens/design_tokens.dart';
import '../common/skin_tokens.dart';
import 'about_screen.dart';
import 'settings_widgets.dart';

/// Настройки в iPod-скине: плоская таблица пунктов, раскрывающихся на месте.
///
/// У iPod не было подменю — была одна таблица, в которой пункт раскрывался
/// строкой ниже (ровно как в старых меню iPod и в «Настройках» первых
/// Android-проигрывателей). Поэтому здесь нет переходов: нажатие на пункт
/// раскрывает его под списком, второе нажатие сворачивает. Переход на
/// отдельный экран означал бы экран, до которого надо доезжать шевроном, а
/// на маленьком графитовом дисплее это лишний шаг без выигрыша.
class SettingsIpodView extends ConsumerStatefulWidget {
  const SettingsIpodView({super.key});

  @override
  ConsumerState<SettingsIpodView> createState() => _SettingsIpodViewState();
}

class _SettingsIpodViewState extends ConsumerState<SettingsIpodView> {
  /// Раскрытый пункт. null — всё свёрнуто.
  ///
  /// Только один пункт за раз: как на настоящем iPod, где открытая строка
  /// занимает место на том же экране, и две открытые половины просто не
  /// поместились бы.
  SettingsSubPage? _open;

  @override
  Widget build(BuildContext context) {
    final h = skinOf(context);
    final id = h.id;
    final t = h.tokens;
    // iPod-скином этот виджет видят только в нём, но проверка лишняя не
    // стоит: при смене темы на лету список должен остаться плоским.
    assert(id.isIpod, 'SettingsIpodView рисуется только в iPod-скине');

    return ListView(
      padding: EdgeInsets.fromLTRB(t.space8, t.space4, t.space8, t.space24),
      children: [
        _row(t, SettingsSubPage.sources, AppIcons.musicNote,
            subtitle: 'Сервисы, токены, подмена'),
        if (_open == SettingsSubPage.sources)
          _expanded(t, const SettingsSourcesBlock()),
        // Внешний вид — единственный пункт, ведущий не «раскрытием», а в
        // маршрут: это общий для обеих тем экран, и переключатель темы живёт
        // именно там. Без этой строки в iPod нельзя было бы сменить оформление.
        IpodListRow(
          tokens: t,
          title: 'Внешний вид',
          subtitle: 'Тема оформления',
          leading: AppIcons.sparkles,
          onTap: () => context.push(Routes.appearance),
        ),
        _row(t, SettingsSubPage.audio, AppIcons.volume,
            subtitle: 'Кроссфейд, тишина, битрейт'),
        if (_open == SettingsSubPage.audio)
          _expanded(t, const SettingsAudioBlock()),
        _row(t, SettingsSubPage.network, AppIcons.radio,
            subtitle: 'DoH, прокси'),
        if (_open == SettingsSubPage.network)
          _expanded(t, const SettingsNetworkBlock()),
        _row(t, SettingsSubPage.accounts, AppIcons.home,
            subtitle: 'Google, Last.fm'),
        if (_open == SettingsSubPage.accounts)
          _expanded(t, const SettingsAccountsBlock()),
        _row(t, SettingsSubPage.data, AppIcons.storage,
            subtitle: 'Копия, память, статистика'),
        if (_open == SettingsSubPage.data)
          _expanded(t, const SettingsDataBlock()),
        _row(t, SettingsSubPage.update, AppIcons.download,
            subtitle: 'Проверка версии'),
        if (_open == SettingsSubPage.update)
          _expanded(t, const SettingsUpdateBlock()),
        _row(t, SettingsSubPage.about, AppIcons.warning,
            subtitle: 'Версия, лицензии'),
        if (_open == SettingsSubPage.about) const _AboutInline(),
      ],
    );
  }

  Widget _row(
    DesignTokens t,
    SettingsSubPage page,
    AppIconData icon, {
    String? subtitle,
  }) {
    final open = _open == page;
    return IpodListRow(
      tokens: t,
      title: settingsPageTitle(page),
      subtitle: subtitle,
      leading: icon,
      selected: open,
      trailing: AppIcon(
        open ? AppIcons.chevronDown : AppIcons.chevronRight,
        size: 18,
        color: (open ? t.accentOn : t.textPrimary)
            .withValues(alpha: (open ? t.accentOn : t.textPrimary).a * 0.7),
      ),
      onTap: () => setState(() => _open = open ? null : page),
    );
  }

  /// Раскрытое содержимое: отступ и вертикальная линия слева — «вложенность»
  /// без вложенности. На iPod не было рамок, но и не было понятия подменю,
  /// поэтому границей служит тонкая линия, а не карточка.
  Widget _expanded(DesignTokens t, Widget child) => Container(
        margin: EdgeInsets.only(left: t.space12),
        padding: EdgeInsets.only(left: t.space8, top: t.space4, bottom: t.space8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: t.separator),
          ),
        ),
        child: child,
      );
}

/// «О приложении» раскрытой строкой — тот же [AboutContent], что и на
/// отдельном экране, но без шапки: перехода тут нет.
class _AboutInline extends StatelessWidget {
  const _AboutInline();

  @override
  Widget build(BuildContext context) {
    final h = skinOf(context);
    final id = h.id;
    final t = h.tokens;
    assert(id.isIpod);
    return Container(
      margin: EdgeInsets.only(left: t.space12),
      padding: EdgeInsets.only(left: t.space8, top: t.space4, bottom: t.space8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.separator)),
      ),
      child: const AboutContent(),
    );
  }
}