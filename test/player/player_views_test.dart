import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/core/widgets/player_visualizer.dart';
import 'package:roundds/design/ipod/ipod_widgets.dart';
import 'package:roundds/design/tokens/design_tokens.dart';
import 'package:roundds/design/tokens/ios_tokens.dart';
import 'package:roundds/design/tokens/ipod_tokens.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/player/ios_player_view.dart';
import 'package:roundds/features/player/ipod_player_view.dart';
import 'package:roundds/features/player/player_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Оба вида плеера и общий ряд управления.
///
/// Плеер — самый важный экран, и ошибка в нём видна сразу: переполнение по
/// высоте, «плавающая» разметка или потерянный колбэк. Поэтому обе вёрстки
/// собираются в тесте целиком, на настоящих токенах скинов.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const track = Track(
    id: 't1',
    title: 'Группа крови',
    artist: 'Кино',
    album: 'Кино',
    source: SourceType.youtube,
    duration: Duration(minutes: 3, seconds: 5),
  );

  PlayerUi ui(DesignTokens tokens, {Track? current, String? error}) {
    final t = current ?? track;
    return PlayerUi(
      tokens: tokens,
      track: t,
      queue: [t],
      index: 0,
      direction: 1,
      isPlaying: true,
      isLoading: false,
      shuffleOn: false,
      repeatActive: false,
      repeatOne: false,
      duration: t.duration ?? Duration.zero,
      error: error,
      liked: false,
      disliked: false,
      downloaded: false,
      downloading: false,
      downloadProgress: null,
      service: t.source,
      originService: null,
      onClose: () {},
      onMore: () {},
      onLyrics: () {},
      onQueue: () {},
      onDownload: () {},
      onAddToPlaylist: () {},
      onLike: () {},
      onDislike: () {},
      onArtist: () {},
      onAlbum: () {},
      onSelectIndex: (_) {},
      onTogglePlay: () {},
      onPrev: () {},
      onNext: () {},
      onShuffle: () {},
      onCycleRepeat: () {},
      onSeek: (_) {},
      onRetry: () {},
    );
  }

  /// Позиция приходит отдельным стримом; в тесте он не нужен — подменяем.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 780),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          positionProvider.overrideWith((ref) => Stream.value(Duration.zero)),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump(); // первый кадр, пока без анимаций
  }

  group('вёрстка плеера', () {
    testWidgets('iOS: обложки, подписи и ряд управления', (tester) async {
      await pump(
        tester,
        IosPlayerView(ui: ui(IosTokens.instance)),
      );

      expect(find.text('Группа крови'), findsWidgets);
      expect(find.text('Кино'), findsWidgets);
      expect(find.byType(PlayerControls), findsOneWidget);
      expect(find.byType(PlayerTools), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iPod: графит, LCD-подписи и тот же ряд управления',
        (tester) async {
      await pump(
        tester,
        IpodPlayerView(ui: ui(IpodTokens.instance)),
      );

      expect(find.byType(GraphiteBackground), findsOneWidget);
      expect(find.text('Группа крови'), findsWidgets);
      expect(find.byType(PlayerControls), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ошибка воспроизведения показывается с кнопкой «Повтор»',
        (tester) async {
      final withError = ui(IosTokens.instance, error: 'Поток недоступен');
      await pump(tester, IosPlayerView(ui: withError));

      expect(find.text('Поток недоступен'), findsOneWidget);
      expect(find.text('Повтор'), findsOneWidget);
    });

    // Регресс на замер: до правки колонка липла к верху и оставляла внизу
    // 237 px пустоты из 780. Теперь панель инструментов должна доходить
    // примерно до низа экрана.
    testWidgets('iPod: содержимое распределено по экрану, а не липнет к верху',
        (tester) async {
      await pump(tester, IpodPlayerView(ui: ui(IpodTokens.instance)));

      final bottom = tester.getRect(find.byType(PlayerTools)).bottom;
      expect(bottom, greaterThan(560),
          reason: 'низ экрана должен быть занят, а не пустовать');
    });

    // Регресс на замер: на паузе 32 полоски по 3 px читались как пунктирная
    // линия над панелью управления. Спектр на паузе не рисуется вовсе.
    testWidgets('iPod: на паузе спектр не рисуется пунктиром', (tester) async {
      final paused = PlayerUi(
        tokens: ui(IpodTokens.instance).tokens,
        track: const Track(
          id: 't1',
          title: 'Группа крови',
          artist: 'Кино',
          source: SourceType.youtube,
        ),
        queue: const [],
        index: 0,
        direction: 1,
        isPlaying: false,
        isLoading: false,
        shuffleOn: false,
        repeatActive: false,
        repeatOne: false,
        duration: const Duration(minutes: 3),
        error: null,
        liked: false,
        disliked: false,
        downloaded: false,
        downloading: false,
        downloadProgress: null,
        service: SourceType.youtube,
        originService: null,
        onClose: () {},
        onMore: () {},
        onLyrics: () {},
        onQueue: () {},
        onDownload: () {},
        onAddToPlaylist: () {},
        onLike: () {},
        onDislike: () {},
        onArtist: () {},
        onAlbum: () {},
        onSelectIndex: (_) {},
        onTogglePlay: () {},
        onPrev: () {},
        onNext: () {},
        onShuffle: () {},
        onCycleRepeat: () {},
        onSeek: (_) {},
        onRetry: () {},
      );
      await pump(tester, IpodPlayerView(ui: paused));

      expect(find.byType(PlayerVisualizer), findsNothing);
    });
  });

  group('PlayerControls', () {
    testWidgets('все пять кнопок вызывают свои колбэки', (tester) async {
      var play = 0;
      var prev = 0;
      var next = 0;
      var shuffle = 0;
      var repeat = 0;

      await pump(
        tester,
        PlayerControls(
          tokens: IosTokens.instance,
          isPlaying: false,
          isLoading: false,
          shuffleOn: false,
          repeatActive: false,
          repeatOne: false,
          onTogglePlay: () => play++,
          onPrev: () => prev++,
          onNext: () => next++,
          onShuffle: () => shuffle++,
          onRepeat: () => repeat++,
        ),
      );

      for (final label in [
        'Играть',
        'Предыдущий трек',
        'Следующий трек',
        'Перемешать',
        'Повтор',
      ]) {
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pump();
      }

      expect([play, prev, next, shuffle, repeat], [1, 1, 1, 1, 1]);
    });
  });
}
