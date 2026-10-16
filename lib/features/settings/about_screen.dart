import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/wordmark.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../common/skin_tokens.dart';

/// Текст дисклеймера.
///
/// Раньше он висел красным блоком вверху настроек и занимал пол-экрана при
/// каждом входе: предупреждение о нарушении правил сервисов важно, но не
/// каждый раз — его место на экране «О приложении», куда приходят читать
/// один раз, а не перечитывают по памяти перед каждой правкой звука.
const String kDisclaimer =
    'Воспроизведение использует неофициальные методы. Это нарушает правила '
    'сервисов и авторские права, может ломаться при их обновлениях, а токен '
    'Яндекса несёт риск блокировки аккаунта. Ответственность за использование '
    '— на вас.';

/// Экран «О приложении»: версия, логотип, дисклеймер, благодарности и
/// лицензии.
///
/// [onBack] null — экран вставлен как блок (например, раскрытая строка меню
/// в iPod); иначе он самостоятельный подэкран со своей шапкой. Отдельный
/// маршрут `/settings/about` открывает его именно так.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    final back = onBack;
    const content = AboutContent();

    // Без «назад» экран вставлен блоком (раскрытая строка меню в iPod) —
    // шапка там была бы лишней, её рисует сама строка.
    if (back == null) return content;

    return Material(
      color: t.background,
      child: Column(
        children: [
          AppHeader(title: 'О приложении', onBack: back),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(t.space16, 0, t.space16, t.space24),
              children: const [content],
            ),
          ),
        ],
      ),
    );
  }
}

/// Содержимое «О приложении» без шапки и без прокрутки.
///
/// Отдельный виджет, потому что iPod показывает этот текст раскрытой строкой
/// меню, а не переходом: там не было подменю, и экран «О приложении» —
/// просто раскрытая строка с текстом под ней.
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(child: _Logo()),
        const SizedBox(height: 8),
        const Center(child: _Version()),
        const SizedBox(height: 24),
        _Panel(
          tokens: t,
          icon: AppIcons.warning,
          title: 'Условия использования',
          body: kDisclaimer,
          tone: t.danger,
        ),
        const SizedBox(height: 16),
        _Panel(
          tokens: t,
          icon: AppIcons.musicNote,
          title: 'Источники',
          body: 'YouTube Music, SoundCloud, Яндекс Музыка, VK Музыка, '
              'Last.fm.\nВоспроизведение идёт внутри приложения, файлы '
              'остаются у вас. Приложение не для Google Play: сборка '
              'распространяется в виде APK.',
        ),
        const SizedBox(height: 16),
        _Panel(
          tokens: t,
          icon: AppIcons.sparkles,
          title: 'Благодарности',
          body: 'Всем, кто присылал баги, токены и терпение, пока обходы '
              'ломались: Yandex Music API, SoundCloud API, VK Audio, '
              'Last.fm API, Material Icons, Inter.',
        ),
        const SizedBox(height: 16),
        _Panel(
          tokens: t,
          icon: AppIcons.library,
          title: 'Лицензии',
          body: 'Flutter и Dart — BSD-3-Clause · Riverpod — MIT · '
              'just_audio — MIT · Dio — BSD-3-Clause · Firebase — Apache-2.0 · '
              'Inter — SIL Open Font License 1.1.',
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Сделано для тех, кому надоело искать музыку в шести приложениях.',
            textAlign: TextAlign.center,
            style: t.micro.copyWith(color: t.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Логотип: фирменные цвета в iOS, монохромная LCD-надпись в iPod.
///
/// Цветной логотип в приложении один — на экране загрузки. Тащить второе
/// цветное пятно на экран «О приложении» означало бы разрушить правило
/// «монохромный iPod», поэтому там печатается просто надпись.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final h = skinOf(context);
    final t = h.tokens;
    if (h.id.isIpod) {
      return Text('vvavve', style: t.title.copyWith(color: t.textPrimary));
    }
    // Кегль — из шкалы токена, а не константой: у скина своя шкала, и число
    // из другого скина сделало бы логотип чужим.
    final size = t.title.fontSize;
    return size == null
        ? Wordmark(color: t.textPrimary)
        : Wordmark(fontSize: size, color: t.textPrimary);
  }
}

/// Версия из установленного пакета.
///
/// Читается асинхронно и может не прийти вообще (нет package_info на
/// нестандартной платформе, тест, битая сборка) — тогда показываем прочерк,
/// а не пустоту: «vvavve —» читается как ошибка вёрстки.
class _Version extends ConsumerWidget {
  const _Version();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = skinOf(context).tokens;
    return FutureBuilder<String>(
      future: _currentVersion(ref),
      builder: (_, snap) => Text(
        snap.data == null || snap.data!.isEmpty
            ? 'версия неизвестна'
            : 'версия ${snap.data} · не для Google Play',
        style: t.micro.copyWith(color: t.textTertiary),
      ),
    );
  }
}

Future<String> _currentVersion(WidgetRef ref) async {
  try {
    return await ref.read(updateServiceProvider).currentVersion();
  } catch (_) {
    return '';
  }
}

/// Плитка с заголовком и текстом: дисклеймер, благодарности, лицензии.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.body,
    this.tone,
  });

  final DesignTokens tokens;
  final AppIconData icon;
  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final tone = this.tone;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 18, color: tone ?? t.accent),
              SizedBox(width: t.space8),
              Expanded(
                child: Text(
                  title,
                  style: t.caption.copyWith(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space8),
          Text(
            body,
            style: t.micro.copyWith(color: t.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}