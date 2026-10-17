import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../features/artist/followed_artists_screen.dart';
import '../../features/charts/charts_screen.dart';
import '../../features/player/equalizer_screen.dart';
import '../../features/player/now_playing_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/blacklist_screen.dart';
import '../../features/settings/diagnostics_screen.dart';
import '../../features/settings/dislikes_screen.dart';
import '../../features/settings/storage_screen.dart';
import '../../features/shell/boot_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/stats/stats_screen.dart';

/// Именованные пути навигации. Используются через context.push(name),
/// чтобы навигация была в одном месте (а не через MaterialPageRoute в
/// каждом виджете) и поддерживала deep links.
///
/// Параметризованные экраны (artist/album/playlist/tracklist) пока
/// остаются на MaterialPageRoute — они требуют path parameters, что
/// в go_router 14 делается через :param и extra. Перевод запланирован
/// вместе с миграцией go_router 14→17 (Этап 9), т.к. там API маршрутов
/// всё равно меняется.
class Routes {
  static const boot = '/boot';
  static const home = '/';
  static const player = '/player';
  static const settings = '/settings';
  static const charts = '/charts';
  static const equalizer = '/equalizer';
  static const appearance = '/settings/appearance';
  static const about = '/settings/about';
  static const stats = '/stats';
  static const storage = '/settings/storage';
  static const blacklist = '/settings/blacklist';
  static const dislikes = '/settings/dislikes';
  static const diagnostics = '/settings/diagnostics';
  static const followedArtists = '/followed-artists';
}

/// Роутер приложения — провайдер, а не глобальная переменная.
///
/// Провайдер нужен по двум причинам. Первая: начальный маршрут зависит от
/// скина (iPod при первом запуске открывается экраном загрузки), а скина в
/// prefs, и прочитать их можно только через контейнер. Вторая: GoRouter держит
/// стек навигации, и глобальный роутер переживал бы смену темы как утечку —
/// а `Provider` пересоздаётся только когда его действительно кто-то сменил,
/// то есть практически никогда.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Читаем, а не слушаем: подписка роутера на скин означала бы пересборку
  // навигации при переключении темы — то есть потерю стека. Тема влияет
  // только на то, КАК отрисован экран, но не на то, какой это маршрут.
  final skin = ref.read(currentSkinProvider);
  final showBoot = skin.id == SkinId.ipod && !ref.read(bootSeenProvider);

  return GoRouter(
    initialLocation: showBoot ? Routes.boot : Routes.home,
    routes: [
      GoRoute(
        path: Routes.boot,
        builder: (context, state) => BootScreen(
          onFinished: () {
            // Помечаем ДО перехода: если следующий кадр не случится (приложение
            // уходит в фон), флаг всё равно должен пережить перезапуск — иначе
            // логотип показывался бы при каждом старте.
            ref.read(bootSeenProvider.notifier).markSeen();
            // GoRouter.of, а не context.go: контекст маршрута уже принадлежит
            // этому роутеру, и это единственный способ уйти с экрана, который
            // сам роутер и поставил.
            GoRouter.of(context).go(Routes.home);
          },
        ),
      ),
      // Корневой маршрут ведёт на оболочку, а разделы внутри неё строит скин
      // (см. HomeShell): роутер не знает, что такое «раздел», и не должен —
      // иначе добавление раздела или скина правило бы его.
      GoRoute(path: Routes.home, builder: (_, __) => const HomeShell()),
      GoRoute(
        path: Routes.player,
        pageBuilder: (context, state) => _playerPage(context, state, ref),
      ),
      // Настройки — тоже скина: [Skin.buildSettings] сам решает, как выглядит
      // экран, а шапку рисует общий AppHeader.
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SkinSettingsRoute(),
      ),
      // Вторичные экраны без параметров — именованные маршруты вместо
      // разрозненных MaterialPageRoute.push.
      GoRoute(path: Routes.charts, builder: (_, __) => const ChartsScreen()),
      GoRoute(
          path: Routes.equalizer, builder: (_, __) => const EqualizerScreen()),
      GoRoute(
          path: Routes.appearance,
          builder: (_, __) => const AppearanceScreen()),
      GoRoute(
        path: Routes.about,
        // maybePop, а не pop: экран должен закрываться и когда его открыли
        // не через роутер (тест, превью, переход из другого кода).
        builder: (context, __) =>
            AboutScreen(onBack: () => Navigator.of(context).maybePop()),
      ),
      GoRoute(path: Routes.stats, builder: (_, __) => const StatsScreen()),
      GoRoute(path: Routes.storage, builder: (_, __) => const StorageScreen()),
      GoRoute(
          path: Routes.blacklist, builder: (_, __) => const BlacklistScreen()),
      GoRoute(
          path: Routes.dislikes, builder: (_, __) => const DislikesScreen()),
      GoRoute(
        path: Routes.diagnostics,
        builder: (_, __) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: Routes.followedArtists,
        builder: (_, __) => const FollowedArtistsScreen(),
      ),
    ],
  );
});

/// Полноэкранный плеер. Содержимое и переход — по скину.
///
/// iOS: страница выезжает справа, как в системной навигации. iPod: проявление
/// без движения — монохромный корпус не «выезжал», он включался. Длительность и
/// кривая тоже из токенов, поэтому смена темы меняет и «характер» открытия.
CustomTransitionPage<void> _playerPage(
  BuildContext context,
  GoRouterState state,
  Ref ref,
) {
  final skin = ref.read(currentSkinProvider);
  final tokens = skin.tokens;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: const NowPlayingScreen(),
    transitionDuration: tokens.motionDuration,
    reverseTransitionDuration: tokens.motionDuration,
    transitionsBuilder: skin.id == SkinId.ipod ? _ipodAppear : _iosSlide,
  );
}

/// iOS-переход: новая страница выезжает справа, уходящая — уходит влево.
Widget _iosSlide(
  BuildContext context,
  Animation<double> anim,
  Animation<double> secondary,
  Widget child,
) {
  final t = _skinTokens(context);
  final enter = CurvedAnimation(parent: anim, curve: t.motionCurve);
  final exit = CurvedAnimation(parent: secondary, curve: t.motionCurve);
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(enter),
    child: SlideTransition(
      // Уходящая страница уезжает на треть экрана, а не целиком: иначе на
      // большом планшете «назад» выглядело бы как перелистывание пустоты.
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.3, 0),
      ).animate(exit),
      child: child,
    ),
  );
}

/// iPod-переход: проявление на месте.
Widget _ipodAppear(
  BuildContext context,
  Animation<double> anim,
  Animation<double> secondary,
  Widget child,
) {
  final t = _skinTokens(context);
  return FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: t.motionCurve),
    child: child,
  );
}

/// Токены для перехода: скин из контекста, а если его там нет (маршрут
/// отрисован вне scope в тесте) — токены текущего скина по умолчанию.
DesignTokens _skinTokens(BuildContext context) =>
    SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ios).tokens;