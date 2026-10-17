import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roundds/core/library_controller.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/core/update_controller.dart';
import 'package:roundds/core/update_service.dart';
import 'package:roundds/core/widgets/app_header.dart';
import 'package:roundds/core/widgets/mini_player.dart';
import 'package:roundds/design/icons/app_icons.dart';
import 'package:roundds/design/ios/ios_widgets.dart';
import 'package:roundds/design/ipod/ipod_widgets.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:roundds/design/tokens/ipod_tokens.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/shell/boot_screen.dart';
import 'package:roundds/features/shell/home_shell.dart';
import 'package:roundds/features/shell/mini_player_shell.dart';
import 'package:roundds/playback/playback_controller.dart';
import 'package:roundds/sync/sync_service.dart';

/// Оболочка, мини-плеер и шапка — то, что должно одинаково работать в двух
/// скинах.
///
/// Проверяем не «красиво», а три контракта: каркас рисует то, что обещает
/// скин, раздел живёт в провайдере (иначе смена темы сбрасывала бы выбор), а
/// мини-плеер и шапка подстраиваются под скин сами.
const _track = Track(
  id: 'id1',
  title: 'Test Title',
  artist: 'Test Artist',
  source: SourceType.soundcloud,
  duration: Duration(minutes: 3, seconds: 7),
);

/// Плеер без аудио: настоящий [PlaybackController] тянет за собой just_audio и
/// audio_service, а тесту нужен только «есть ли текущий трек».
class _FakePlayback implements PlaybackController {
  _FakePlayback({this.current});

  @override
  final Track? current;

  @override
  bool isPlaying = false;

  @override
  bool isLoading = false;

  int toggles = 0;

  @override
  Future<void> togglePlay() async => toggles++;

  // Провайдер только подписывается на изменения — слушатели не нужны.
  @override
  void addListener(VoidCallback _) {}

  @override
  void removeListener(VoidCallback _) {}

  @override
  void notifyListeners() {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Синхронизация без Firebase: оболочка только слушает предложение «продолжить
/// сессию», и в тесте оно не появляется.
class _FakeSync implements SyncService {
  @override
  void addListener(VoidCallback _) {}

  @override
  void removeListener(VoidCallback _) {}

  @override
  void notifyListeners() {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Проверка обновлений без сети: тесту не нужен поход на GitHub, а незакрытый
/// HTTP-запрос на конце теста роняет его таймером.
class _NoUpdateController extends UpdateController {
  _NoUpdateController() : super(UpdateService(Dio()));

  @override
  Future<UpdateInfo?> check() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ios = skinFor(SkinId.ios);
  final ipod = skinFor(SkinId.ipod);

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('каркас скина', () {
    testWidgets('iOS рисует нижнюю панель, а не меню', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ios.buildShell(
            context,
            const SizedBox.expand(),
            sectionIndex: 0,
            onSection: (_) {},
            onSettings: () {},
          ),
        ),
      ));
      expect(find.byType(IosTabBar), findsOneWidget);
      expect(find.byType(IpodMenuBar), findsNothing);
      expect(find.byType(GraphiteBackground), findsNothing);
    });

    testWidgets('iPod рисует меню и графитовый фон', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ipod.buildShell(
            context,
            const SizedBox.expand(),
            sectionIndex: 2,
            onSection: (_) {},
            onSettings: () {},
          ),
        ),
      ));
      expect(find.byType(IpodMenuBar), findsOneWidget);
      expect(find.byType(GraphiteBackground), findsOneWidget);
      expect(find.byType(IosTabBar), findsNothing);
    });
  });

  group('HomeShell', () {
    /// Оболочка целиком: подменяем только то, что ходит в сеть/на диск.
    Future<void> pumpShell(
      WidgetTester tester, {
      String? skin,
      GoRouter? router,
    }) async {
      final prefs = await prefsWith({
        'onboarded': true,
        if (skin != null) SkinController.storageKey: skin,
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          playbackProvider.overrideWith((ref) => _FakePlayback()),
          syncServiceProvider.overrideWith((ref) => _FakeSync()),
          libraryProvider.overrideWith((ref) => LibraryController(prefs)),
          updateControllerProvider.overrideWith((ref) => _NoUpdateController()),
        ],
        child: router == null
            ? const MaterialApp(home: HomeShell())
            : MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      // Контент разделов — настоящие сетевые провайдеры: в тестовом окружении
      // запросы дают 400, и youtube_explode планирует retry-таймеры (500 мс+).
      // Прогоняем время, чтобы они отработали и не роняли тест инвариантом
      // «Timer is still pending».
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('переключение раздела меняет sectionIndex и экран',
        (tester) async {
      await pumpShell(tester);
      expect(tester.widget<IosTabBar>(find.byType(IosTabBar)).currentIndex, 0);

      await tester.tap(find.text(SkinSection.search.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<IosTabBar>(find.byType(IosTabBar)).currentIndex, 1);
      // Контент раздела — настоящий экран поиска, не заглушка.
      expect(find.text('Поиск по всем сервисам'), findsOneWidget);
    });

    testWidgets('смена темы не сбрасывает выбранный раздел', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text(SkinSection.library.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Переключаем скин так же, как это делает настройка оформления.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeShell)),
      );
      await container.read(skinProvider.notifier).select(SkinId.ipod);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Рамка сменилась на меню iPod, раздел при этом тот же (заголовок
      // «Медиатека» в меню, реальная медиатека под ним).
      expect(find.byType(IpodMenuBar), findsOneWidget);
      expect(find.text(SkinSection.library.title), findsOneWidget);
    });

    testWidgets('шестерёнка меню iPod открывает экран настроек',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeShell()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const Scaffold(body: Text('НАСТРОЙКИ')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpShell(tester, skin: 'ipod', router: router);

      // На первом разделе у iPod-меню одна иконка — шестерёнка настроек.
      await tester.tap(find.descendant(
        of: find.byType(IpodMenuBar),
        matching: find.byType(AppIcon),
      ));
      await tester.pumpAndSettle();
      expect(find.text('НАСТРОЙКИ'), findsOneWidget);
    });
  });

  group('мини-плеер', () {
    /// Только мини-плеер: скин берётся из prefs, плеер подменён.
    Future<void> pumpMini(
      WidgetTester tester,
      Track? track, {
      String? skin,
      GoRouter? router,
      _FakePlayback? playback,
    }) async {
      final prefs = await prefsWith({
        if (skin != null) SkinController.storageKey: skin,
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          playbackProvider.overrideWith(
              (ref) => playback ?? _FakePlayback(current: track)),
          prefsProvider.overrideWithValue(prefs),
        ],
        child: router == null
            ? const MaterialApp(home: Scaffold(body: MiniPlayer()))
            : MaterialApp.router(routerConfig: router),
      ));
    }

    GoRouter shellRouter() {
      final r = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: MiniPlayer()),
        ),
        GoRoute(
          path: '/player',
          builder: (_, __) => const Scaffold(body: Center(child: Text('ПЛЕЕР'))),
        ),
      ]);
      addTearDown(r.dispose);
      return r;
    }

    testWidgets('без текущего трека не показан', (tester) async {
      await pumpMini(tester, null, router: shellRouter());

      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.byType(IosMiniPlayer), findsNothing);
      expect(find.text('Test Title'), findsNothing);
    });

    testWidgets('с треком показан в виде iOS-карточки', (tester) async {
      await pumpMini(tester, _track, router: shellRouter());

      expect(find.byType(IosMiniPlayer), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    });

    testWidgets('в iPod это строка прибора с подписью времени', (tester) async {
      await pumpMini(tester, _track, skin: 'ipod', router: shellRouter());

      expect(find.byType(IpodMiniPlayer), findsOneWidget);
      expect(find.byType(IosMiniPlayer), findsNothing);
      expect(find.text('3:07'), findsOneWidget);
    });

    testWidgets('тап открывает полноэкранный плеер', (tester) async {
      await pumpMini(tester, _track, router: shellRouter());

      await tester.tap(find.text('Test Title'));
      await tester.pumpAndSettle();
      expect(find.text('ПЛЕЕР'), findsOneWidget);
    });

    testWidgets('кнопка play/pause переключает воспроизведение',
        (tester) async {
      final playback = _FakePlayback(current: _track);
      await pumpMini(tester, _track,
          router: shellRouter(), playback: playback);

      // Кнопка play — последняя иконка в ряду (первая — нота в заглушке
      // обложки, она тоже AppIcon после перевода artwork на скин-иконки).
      await tester.tap(find.descendant(
        of: find.byType(IosMiniPlayer),
        matching: find.byType(AppIcon).last,
      ));
      await tester.pump();
      expect(playback.toggles, 1);
    });
  });

  group('AppHeader', () {
    Future<void> pumpHeader(WidgetTester tester, SkinId id, Widget child) =>
        tester.pumpWidget(MaterialApp(
          home: SkinScope(skin: skinFor(id), child: Scaffold(body: child)),
        ));

    testWidgets('iOS показывает крупный заголовок и кнопки', (tester) async {
      await pumpHeader(
        tester,
        SkinId.ios,
        AppHeader(title: 'Настройки', onBack: () {}, onSettings: () {}),
      );
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.byType(AppIcon), findsNWidgets(2),
          reason: 'назад слева и шестерёнка справа');
      expect(find.byType(MarqueeTitle), findsNothing);
    });

    testWidgets('iPod показывает бегущий заголовок высоты меню',
        (tester) async {
      await pumpHeader(
        tester,
        SkinId.ipod,
        AppHeader(title: 'Настройки', onSettings: () {}),
      );
      expect(find.byType(IpodAppHeader), findsOneWidget);
      expect(find.byType(MarqueeTitle), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
      expect(tester.getSize(find.byType(IpodAppHeader)).height,
          IpodTokens.menuBarHeight);
    });
  });

  group('экран загрузки iPod', () {
    testWidgets('рисует логотип и по таймеру сообщает о готовности',
        (tester) async {
      var finished = 0;
      await tester.pumpWidget(MaterialApp(
        home: SkinScope(
          skin: ipod,
          child: BootScreen(
            onFinished: () => finished++,
            minimumDuration: const Duration(milliseconds: 600),
          ),
        ),
      ));
      expect(find.textContaining('vvavve'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(finished, 0, reason: 'минимальная длительность ещё не вышла');
      await tester.pump(const Duration(milliseconds: 700));
      expect(finished, 1);
      expect(find.text('Готово'), findsOneWidget);
    });

    test('флаг «показывали» запоминается в prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c.dispose);

      expect(c.read(bootSeenProvider), isFalse);
      c.read(bootSeenProvider.notifier).markSeen();
      expect(prefs.getBool(BootSeenController.storageKey), isTrue);
    });
  });
}