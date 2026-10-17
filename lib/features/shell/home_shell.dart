import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/update_flow.dart';
import '../../core/widgets/app_header.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';
import '../../playback/playback_controller.dart';
import '../../sync/sync_service.dart' show SyncService;
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'mini_player_shell.dart';

/// Текущий раздел оболочки.
///
/// В провайдере, а не в поле состояния виджета, по двум причинам. Первая и
/// главная: оболочка целиком перестраивается при смене скина, и состояние,
/// лежащее в поле [State], при такой пересборке обнулилось бы — пользователь
/// возвращался бы на «Главную» каждый раз, как меняет оформление. Вторая:
/// раздел должен пережить переход в полноэкранный плеер (он лежит поверх
/// оболочки отдельным маршрутом) и возврат обратно.
class ShellSectionController extends Notifier<SkinSection> {
  @override
  SkinSection build() => SkinSection.values.first;

  /// Переключение по индексу — индекс приходит из каркаса скина (панель iOS,
  /// шевроны iPod). Выход за границы игнорируем: скины считают разделы по
  /// [SkinSection.values], но лишний тап не должен ронять экран.
  void select(int index) {
    if (index < 0 || index >= SkinSection.values.length) return;
    state = SkinSection.values[index];
  }
}

final shellSectionProvider =
    NotifierProvider<ShellSectionController, SkinSection>(
        ShellSectionController.new);

/// Главная оболочка: каркас скина, переключаемый раздел, баннер обновления и
/// мини-плеер.
///
/// Оболочка ничего не знает об устройстве скина: что именно переключает
/// разделы (нижняя панель или меню с шевронами), рисует [Skin.buildShell], а
/// какой экран показывать — [Skin.buildSection]. Поэтому добавление третьего
/// скина не трогает этот файл вовсе.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// Плеер вне оболочки живёт дольше неё, поэтому ссылку на него держим в поле:
  /// в [dispose] уже нельзя читать провайдеры (Riverpod запрещает `ref` после
  /// размонтирования).
  late final PlaybackController _playback;

  @override
  void initState() {
    super.initState();
    // Тихая авто-проверка обновлений + онбординг после первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkForUpdate(context, ref, silent: true);
      _maybeOnboard();
    });
    // SC Go+: предложить сыграть с другого источника вместо молчаливой
    // подмены. HomeShell — единственный постоянно смонтированный Scaffold
    // (полноэкранный плеер лежит поверх него как отдельный route), поэтому
    // снекбар всегда есть куда показать, на каком бы экране ни был пользователь.
    _playback = ref.read(playbackProvider);
    _playback.onGoPlusOffer = _showGoPlusOffer;
  }

  @override
  void dispose() {
    // Колбэк переживает оболочку и указывал бы на снятый State: предложение
    // Go+ может прийти, когда оболочки уже нет.
    _playback.onGoPlusOffer = null;
    super.dispose();
  }

  void _showGoPlusOffer(Track native, Track offer) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text('«${native.title}» — доступен только по подписке '
          'SoundCloud Go+'),
      action: SnackBarAction(
        label: 'Играть с ${offer.source.label}',
        onPressed: () => _playback.acceptGoPlusOffer(),
      ),
      duration: const Duration(seconds: 10),
    ));
  }

  /// Первый запуск с пустой библиотекой → показываем онбординг. Если лайки уже
  /// есть (напр. импорт YTM) — сидов достаточно, онбординг не нужен.
  void _maybeOnboard() {
    final prefs = ref.read(prefsProvider);
    if (prefs.getBool('onboarded') ?? false) return;
    final lib = ref.read(libraryProvider);
    if (lib.liked.isNotEmpty || lib.history.isNotEmpty) {
      prefs.setBool('onboarded', true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const OnboardingScreen(),
    ));
  }

  /// Сессия с другого устройства: предлагаем продолжить, но не подменяем
  /// очередь молча — здесь мог быть свой собранный список, а браузер всё равно
  /// не даст заиграть без нажатия.
  void _watchPendingSession() {
    ref.listen<SyncService>(syncServiceProvider, (_, sync) {
      final pending = sync.pendingSession;
      final track = pending?.current;
      if (pending == null || track == null || !mounted) return;
      final where = pending.deviceLabel == null
          ? 'с другого устройства'
          : 'с устройства «${pending.deviceLabel}»';
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text('Продолжить «${track.title}» $where?'),
        action: SnackBarAction(
          label: 'Продолжить',
          // Снимок захвачен здесь: предложение снимается сразу, чтобы не
          // всплывать повторно, а нажатие должно сработать и после этого.
          onPressed: () => ref.read(syncServiceProvider).adoptSession(pending),
        ),
        duration: const Duration(seconds: 12),
      ));
      // Молчаливый отказ тоже решение: если пользователь не нажал, повторно
      // навязываться не будем.
      sync.dismissPendingSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    _watchPendingSession();
    // Один watch на скин: смена темы перестраивает оболочку целиком, и два
    // watch'а (skinProvider + currentSkinProvider) заставили бы дерево
    // пересобираться в два прохода.
    final skin = ref.watch(currentSkinProvider);
    final section = ref.watch(shellSectionProvider);
    final tokens = skin.tokens;

    // SkinScope ставим здесь, а не только в app.dart: оболочка — корень
    // приложения для своих экранов, и её нельзя ставить в зависимость от того,
    // обернули ли её кто-то снаружи. Вложенные scope'ы не конфликтуют: верхний
    // отдаёт тот же скин.
    return SkinScope(
      skin: skin,
      child: Builder(builder: (context) {
        return skin.buildShell(
          context,
          Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: tokens.motionDuration,
                  switchInCurve: tokens.motionCurve,
                  switchOutCurve: tokens.motionCurve,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      // Небольшой сдвиг снизу: раздел «выезжает» из-под шапки,
                      // как в системной навигации. Сдвиг крошечный — крупный
                      // сдвиг читался бы как «экран уехал».
                      position: Tween(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(section),
                    child: _sectionBody(section),
                  ),
                ),
              ),
              const _UpdateBanner(),
              const ShellMiniPlayer(),
            ],
          ),
          sectionIndex: section.index,
          onSection: (i) =>
              ref.read(shellSectionProvider.notifier).select(i),
          onSettings: () => context.push(Routes.settings),
        );
      }),
    );
  }
}

/// Какой тонкий экран показывает раздел.
///
/// Контент разделов строится здесь, а не в скине: экраны (HomeScreen и
/// соседи) сами выбирают вёрстку по скину через SkinScope, поэтому
/// добавление скина не требует править этот switch, а добавление раздела —
/// одна строка здесь и одна в SkinSection.
Widget _sectionBody(SkinSection section) => switch (section) {
      SkinSection.home => const HomeScreen(),
      SkinSection.search => const SearchScreen(),
      SkinSection.library => const LibraryScreen(),
      SkinSection.stats => const StatsScreen(),
    };

/// Экран настроек: собирается скином, как и разделы.
///
/// Отдельный маршрут, а не раздел оболочки: настройки в iOS открываются
/// шестерёнкой, а в iPod — пунктом меню, и держать их «пятым разделом»
/// значило бы заставлять панель рисовать то, чего в ней нет.
class SkinSettingsRoute extends ConsumerWidget {
  const SkinSettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(currentSkinProvider);
    final tokens = skin.tokens;
    return SkinScope(
      skin: skin,
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: tokens.background,
          body: Column(
            children: [
              AppHeader(
                title: 'Настройки',
                // maybePop вместо context.pop: экран должен закрываться и тогда,
                // когда его открыли не через роутер (тест, превью).
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const Expanded(child: SettingsScreen()),
              const ShellMiniPlayer(),
            ],
          ),
        );
      }),
    );
  }
}

/// Плавающий баннер обновления: прогресс фоновой загрузки и кнопка
/// «Установить», когда APK скачан (установить можно в любой момент).
///
/// Оформлен токенами скина, а не палитрой Material-темы: баннер висит поверх
/// любого раздела, и в iPod-меню он обязан быть частью прибора, а не
/// плашкой из чужой системы.
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.watch(updateControllerProvider);
    if (!ctl.bannerVisible) return const SizedBox.shrink();
    final tokens = SkinScope.of(context).tokens;
    final version = ctl.info?.version ?? '';

    if (ctl.isDownloading) {
      final pct = (ctl.progress * 100).round();
      return Container(
        color: tokens.surface,
        padding: EdgeInsets.fromLTRB(
          tokens.space16,
          tokens.space8,
          tokens.space16,
          tokens.space8,
        ),
        child: Row(
          children: [
            // Своя полоса вместо CircularProgressIndicator: кольцо на
            // монохромном экране iPod выглядело бы как чужой элемент, а полоса
            // читается одинаково в обоих скинах.
            SizedBox(
              width: tokens.space24,
              child: LinearProgressIndicator(
                value: ctl.progress == 0 ? null : ctl.progress,
                minHeight: tokens.space4,
                color: tokens.accent,
                backgroundColor: tokens.separator,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Text(
                'Загрузка обновления $version… $pct%',
                style: tokens.caption.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    // Готово к установке.
    return Container(
      color: tokens.surface,
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space2,
        tokens.space4,
        tokens.space2,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.downloadDone, size: 20, color: tokens.accent),
          SizedBox(width: tokens.space8),
          Expanded(
            child: Text(
              'Обновление $version готово',
              style: tokens.caption
                  .copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          // Кнопки здесь — системные (Material), потому что это простой
          // баннер поверх приложения, а не элемент оформления скина: у него
          // нет своей геометрии ни в одном из скинов, и рисовать его вручную
          // значило бы повторить TextButton в двух местах.
          TextButton(
            onPressed: () => ref.read(updateControllerProvider).install(),
            child: const Text('Установить'),
          ),
          IconButton(
            icon: AppIcon(AppIcons.close, size: 18, color: tokens.textSecondary),
            tooltip: 'Скрыть',
            onPressed: () =>
                ref.read(updateControllerProvider).dismissBanner(),
          ),
        ],
      ),
    );
  }
}