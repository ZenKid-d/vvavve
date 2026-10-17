import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/library_controller.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/core/settings_controller.dart' as core;
import 'package:roundds/core/update_controller.dart';
import 'package:roundds/core/update_service.dart';
import 'package:roundds/core/downloads_controller.dart';
import 'package:roundds/data/aggregator.dart';
import 'package:roundds/data/sources/soundcloud_source.dart';
import 'package:roundds/data/sources/vk_source.dart';
import 'package:roundds/data/sources/yandex_source.dart';
import 'package:roundds/l10n/gen/app_localizations.dart';
import 'package:roundds/playback/playback_controller.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/album/album_screen.dart';
import 'package:roundds/features/charts/charts_screen.dart';
import 'package:roundds/features/common/track_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// artworkUrl null — Artwork рисует градиент-заглушку, сеть не дёргается.
Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      source: SourceType.soundcloud,
    );

/// Плеер без аудио: настоящий контроллер тянет just_audio и audio_service,
/// а экрану нужен только «есть ли текущий трек» (мини-плеер).
class _FakePlayback implements PlaybackController {
  @override
  Track? get current => null;

  @override
  bool isPlaying = false;

  @override
  bool isLoading = false;

  @override
  Future<void> togglePlay() async {}

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

/// Смоук вторичных экранов в обеих темах: рендер без исключений и ключевые
/// подписи. Содержимое экранов деградирует до заглушек без сети — это норма,
/// проверяем не данные, а что экран не падает на нулевом состоянии.
void main() {
  for (final id in SkinId.values) {
    group('тема ${id.name}', () {
      Future<void> pump(WidgetTester tester, Widget child) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        FlutterSecureStorage.setMockInitialValues({});
        final dio = Dio();
        final soundcloud = SoundcloudSource(dio);
        final aggregator = Aggregator({
          SourceType.youtube: SoundcloudSource(dio),
          SourceType.soundcloud: soundcloud,
          SourceType.yandex: YandexSource(dio),
          SourceType.vk: VkSource(dio),
        });
        final settings = core.SettingsController(
          prefs: prefs,
          secure: const FlutterSecureStorage(),
          yandex: YandexSource(dio),
          soundcloud: soundcloud,
          vk: VkSource(dio),
          aggregator: aggregator,
        );
        await settings.load();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => settings),
            playbackProvider.overrideWith((ref) => _FakePlayback()),
            libraryProvider.overrideWith((ref) => LibraryController(prefs)),
            updateControllerProvider.overrideWith(
                (ref) => UpdateController(UpdateService(Dio()))),
            // Экраны читают загрузки при сборке — подменяем пустым
            // контроллером (как в downloads_controller_test).
            downloadsProvider.overrideWith(
                (ref) => DownloadsController(prefs, Dio(), Aggregator(const {}))),
          ],
          child: SkinScope(
            skin: skinFor(id),
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ru'),
              home: child,
            ),
          ),
        ));
        await tester.pump();
        // Прогоняем одноразовые таймеры (retry-задержки, вопросы图片均来源网络
        // в тестовом окружении дают 400 → интерцептор ставит Future.delayed):
        // иначе тест падает с «Timer is still pending».
        await tester.pump(const Duration(seconds: 2));
      }

      testWidgets('TrackListScreen рендерится и показывает треки',
          (tester) async {
        await pump(
          tester,
          TrackListScreen(
            title: 'Список',
            tracks: [_track('a'), _track('b')],
          ),
        );
        expect(find.text('Track a'), findsOneWidget);
        expect(find.text('Слушать всё'), findsOneWidget);
        expect(find.text('Радио'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('TrackListScreen пустое состояние не падает', (tester) async {
        await pump(tester, const TrackListScreen(title: 'Список'));
        expect(find.text('Пусто'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AlbumScreen рендерится с пустым треклистом', (tester) async {
        await pump(tester, AlbumScreen(seed: _track('seed')));
        // Плеер фоновой музыки не поднят в тесте — экран обязан отработать
        // деградацию (AlbumResult.fromSeed от трека-заглушки).
        expect(find.textContaining('Альбом'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ChartsScreen показывает ряды включённых источников',
          (tester) async {
        // SettingsController по умолчанию включает все источники.
        await pump(tester, const ChartsScreen());
        expect(find.textContaining('Топ сейчас'), findsWidgets);
        expect(find.textContaining('Свежие релизы'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  }
}