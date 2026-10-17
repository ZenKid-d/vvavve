/// Минимальные примитивы настроек для двух тем. Без кастомного фреймворка:
/// стандартные Material-виджеты, цвет/форма из токенов скина, иконки —
/// через AppIcon. Всё, что нужно экранам, работает, лишнего нет.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/update_flow.dart';
import '../../core/widgets/app_header.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../common/skin_tokens.dart';
import '../common/track_row.dart';
import 'settings_controller.dart'
    show SettingsCopy, UpdateAction, updateTile;

/// Подэкраны настроек. Внутреннее состояние, не маршруты.
enum SettingsSubPage { sources, audio, network, accounts, data, update, about }

String settingsPageTitle(SettingsSubPage page) => switch (page) {
      SettingsSubPage.sources => SettingsCopy.sources,
      SettingsSubPage.audio => SettingsCopy.audio,
      SettingsSubPage.network => SettingsCopy.network,
      SettingsSubPage.accounts => 'Аккаунты',
      SettingsSubPage.data => 'Данные',
      SettingsSubPage.update => SettingsCopy.update,
      SettingsSubPage.about => 'О приложении',
    };

/// Подэкран настроек: фон из токенов скина, шапка с «назад».
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return Material(
      color: t.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(title: title, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок секции списка.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    // Токены через skinOf: эти примитивы рисуются в обоих скинах, а контекст
    // может оказаться вне SkinScope (тест, превью) — там берём iOS по умолчанию.
    final t = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space16, bottom: t.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            // Кеглей в скин-слое быть не должно — берём шаг шкалы скина.
            style: t.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: t.space2),
              child: Text(
                subtitle!,
                style: t.micro.copyWith(color: t.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsGap extends StatelessWidget {
  const SettingsGap(this.h, {super.key});
  final double h;
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space4),
      child: Text(
        text,
        style: t.micro.copyWith(color: t.textTertiary),
      ),
    );
  }
}

/// Строка-действие: текст слева, стрелка справа.
///
/// Рисуется общим [SkinMenuRow], а не [ListTile]: у ListTile свои цвета
/// Material-темы, и в iPod-скине строка не стала бы инвертированным блоком.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.active = false,
  });

  final String title;
  final String? subtitle;

  /// Иконка из [AppIcons] — не готовый [AppIcon]: виджет строки сам решает,
  /// каким кеглем и цветом рисовать глиф в каждом скине.
  final AppIconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// «Активный» пункт только в iPod рисуется инверсией (цветом его не
  /// выразить); в iOS скин игнорирует пометку.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return SkinMenuRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      // Шеврон рисуем сами, а не полагаемся на авто-шеврон IpodListRow: в
      // iOS-скине строка без trailing осталась бы «тупиком» без успеха.
      trailing: trailing ??
          (onTap != null
              ? AppIcon(AppIcons.chevronRight, size: 18, color: t.textTertiary)
              : null),
      onTap: onTap,
      selected: active,
    );
  }
}

/// Переключатель в строке.
///
/// Собственный [Switch] в токенной строке вместо [SwitchListTile]: у Material
/// плитки свои цвета активного состояния, и в монохромном iPod тумблер
/// подсветился бы «чужим» акцентом.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppIconData? leading;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return SkinMenuRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: t.accent,
      ),
    );
  }
}

/// Поле токена: текстовая строка в рамке.
class SettingsTokenField extends StatelessWidget {
  const SettingsTokenField({
    super.key,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.readOnly = false,
    required this.filledColor,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final bool readOnly;
  final Color filledColor;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      // Текст в поле — из шкалы скина: системный кегль Material в iPod
      // выбивался бы из «LCD»-типографики.
      style: t.body.copyWith(color: t.textPrimary),
      decoration: InputDecoration(
        hintText: hintText ?? '',
        hintStyle: t.body.copyWith(color: t.textTertiary),
        filled: true,
        fillColor: filledColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Кнопка действия.
class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return FilledButton(
      onPressed: onPressed,
      style: style ??
          FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.accentOn,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusPill),
            ),
          ),
      child: child,
    );
  }
}

/// Блок обновления.
class SettingsUpdateBlock extends ConsumerWidget {
  const SettingsUpdateBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = updateTile(ref.watch(updateControllerProvider));
    final t = SkinScope.of(context).tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsActionRow(
          title: tile.title,
          subtitle: tile.subtitle,
          leading: AppIcons.systemUpdate,
          trailing: tile.action == UpdateAction.none
              ? (tile.busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : null)
              : AppIcon(
                  tile.action == UpdateAction.install
                      ? AppIcons.downloadDone
                      : AppIcons.chevronRight,
                  size: 20,
                  color: t.accent,
                ),
          onTap: tile.action == UpdateAction.none
              ? null
              : () {
                  if (tile.action == UpdateAction.check) {
                    checkForUpdate(context, ref, silent: false);
                  } else if (tile.action == UpdateAction.install) {
                    ref.read(updateControllerProvider).install();
                  }
                },
        ),
        if (tile.busy) ...[
          const SettingsGap(2),
          const SettingsNote('Загрузка идёт в фоне — можно продолжать слушать.'),
        ],
      ],
    );
  }
}

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Switch(value: value, onChanged: onChanged);
}

/// Простые обёртки подэкрана — полная вёрстка в темах.
class SettingsSourcesBlock extends StatelessWidget {
  const SettingsSourcesBlock({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SettingsAudioBlock extends StatelessWidget {
  const SettingsAudioBlock({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SettingsNetworkBlock extends StatelessWidget {
  const SettingsNetworkBlock({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SettingsAccountsBlock extends StatelessWidget {
  const SettingsAccountsBlock({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SettingsDataBlock extends StatelessWidget {
  const SettingsDataBlock({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
