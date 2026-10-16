import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/library_controller.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/data/lastfm_service.dart';
import 'package:roundds/data/recommendation_service.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/home/home_controller.dart';
import 'package:roundds/features/home/ios_home_view.dart';
import 'package:roundds/features/home/ipod_home_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Смоук главных в двух скинах. Логика проверяется в home_controller_test, но
// именно тут ловится то, чего не видит анализатор: слайвер в адаптере и
// переполнение в сетке — это ассерты времени выполнения, и без сборки экрана
// они дожидаются пользователя.

Track _t(String id, String artist) => Track(
      id: id,
      title: 'Трек $id',
      artist: artist,
      source: SourceType.youtube,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LibraryController> libWith([Map<String, Object>? initial]) async {
    SharedPreferences.setMockInitialValues(initial ?? {});
    final prefs = await SharedPreferences.getInstance();
    return LibraryController(prefs);
  }

  Future<void> pumpHome(WidgetTester tester, LibraryController lib) async {
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          libraryProvider.overrideWith((ref) => lib),
          feedProvider
              .overrideWith((ref) async => [_t('1', 'A'), _t('2', 'B')]),
          recommendationsProvider.overrideWith(
            (ref) async => [
              RecoRow('Для тебя', [_t('3', 'C')])
            ],
          ),
          dailyPlaylistsProvider.overrideWith(
            (ref) async => [
              RecoRow('Плейлист дня', [_t('4', 'D')])
            ],
          ),
          lastfmServiceProvider.overrideWithValue(
            LastfmService(Dio(), const FlutterSecureStorage()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: IosHomeView())),
      ),
    );
    await tester.pump();
  }

  testWidgets('iOS главная собирается без переполнений', (tester) async {
    final lib = await libWith(null);
    await lib.pushHistory(_t('1', 'Артист'));
    await lib.pushHistory(_t('2', 'Артист'));
    await pumpHome(tester, lib);
    expect(find.text('Моя волна'), findsOneWidget);
    expect(find.text('Продолжить слушать'), findsOneWidget);
    expect(find.text('Новинки и чарты'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPod главная: меню и честное пустое состояние', (tester) async {
    final lib = await libWith(null);
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          libraryProvider.overrideWith((ref) => lib),
        ],
        child: const MaterialApp(
          home: Scaffold(body: IpodHomeView()),
        ),
      ),
    );
    await tester.pump();
    for (final label in [
      'Плейлисты',
      'Артисты',
      'Альбомы',
      'Треки',
      'Жанры',
      'Избранное',
      'Загрузки',
      'Статистика',
      'Настройки',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Пока нечего слушать'), findsOneWidget);
    expect(find.text('Моя волна'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPod главная: история выводится строками', (tester) async {
    final lib = await libWith(null);
    await lib.pushHistory(_t('1', 'Артист'));
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          libraryProvider.overrideWith((ref) => lib),
        ],
        child: const MaterialApp(home: Scaffold(body: IpodHomeView())),
      ),
    );
    await tester.pump();
    expect(find.text('Продолжить слушать'), findsOneWidget);
    expect(find.text('Пока нечего слушать'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
