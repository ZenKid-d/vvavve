/// Логика главного экрана: провайдеры данных, правила фильтрации и действия,
/// общие для обоих скинов.
///
/// Вынесено из `home_screen.dart`, потому что главная теперь рисуется в двух
/// видах (iOS и iPod), а провайдеры и правила у них общие. Держать их в виджете
/// означало бы либо дублирование, либо «экран решает за данные».
///
/// Всё, что можно проверить без сети и без виджетов, вынесено в чистые функции
/// ([filterTracks], [filterRows], [dedupeByUid], [greetingFor]) — на них есть
/// тесты в `test/home/home_controller_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/recs/recs_providers.dart';
import '../../data/recs/wave_mode.dart';
import '../../data/recs/wave_mood.dart';
import '../../data/recommendation_service.dart';
import '../../domain/models/track.dart';

// ──────────────────────────────── Провайдеры ────────────────────────────────

/// Лента главного экрана — микс из всех включённых источников.
final feedProvider = FutureProvider<List<Track>>((ref) async {
  ref.watch(settingsProvider);
  return ref.read(aggregatorProvider).feed();
});

/// Персональные ряды главной. Recs v2: строит движок волны (профиль вкуса +
/// кандидаты + скоринг + anti-repetition), а не сырые similar-эндпоинты v1.
final recommendationsProvider = FutureProvider<List<RecoRow>>((ref) async {
  ref.watch(settingsProvider);
  final lib = ref.read(libraryProvider);
  if (lib.history.isEmpty && lib.liked.isEmpty) return const [];
  return ref.read(waveEngineProvider).buildHomeRows();
});

/// Дневные плейлисты («Плейлист дня», «Дежавю») — генерятся раз в сутки,
/// кэшируются в БД с датой.
final dailyPlaylistsProvider = FutureProvider<List<RecoRow>>((ref) async {
  ref.watch(settingsProvider);
  final lib = ref.read(libraryProvider);
  if (lib.history.isEmpty && lib.liked.isEmpty) return const [];
  return ref.read(waveEngineProvider).dailyPlaylists();
});

// ─────────────────────────────── Чистые функции ─────────────────────────────

/// Жанры для радио. Список короткий и постоянный: это «быстрый вход» в жанр,
/// а не поиск — полный список жанров живёт в поиске.
const List<String> homeGenres = [
  'Поп',
  'Рок',
  'Хип-хоп',
  'Электроника',
  'Инди',
  'Джаз',
  'Классика',
  'Метал',
];

/// Сколько последних треков показываем в «Продолжить слушать».
///
/// История хранится обрезанной до [LibraryController.maxHistory], но выводить
/// её целиком на главной незачем: это лента, а не архив, и остальные ряды
/// должны остаться на первом экране.
const int continueListeningLimit = 20;

/// Дедуп по [Track.uid] с сохранением первого вхождения.
///
/// Нужен потому, что один и тот же трек может прийти в ряд из нескольких
/// провайдеров-кандидатов (движок волны склеивает их выдачу). Ряд — это
/// «подборка», и одинаковые пластинки подряд читаются как ошибка.
List<Track> dedupeByUid(Iterable<Track> tracks) {
  final seen = <String>{};
  return [
    for (final t in tracks)
      if (seen.add(t.uid)) t,
  ];
}

/// Треки для показа: без чёрного списка и без повторов.
///
/// [isBlacklisted] передаётся функцией, а не контроллером медиатеки, чтобы
/// правило можно было проверить в тесте без хранилища.
List<Track> filterTracks(
  Iterable<Track> tracks,
  bool Function(String artist) isBlacklisted,
) {
  final seen = <String>{};
  return [
    for (final t in tracks)
      // uid запоминаем даже для отсечённого трека: иначе «первый» экземпляр
      // мог бы пропустить в выдачу второй, а это тот же самый трек.
      if (seen.add(t.uid) && !isBlacklisted(t.artist)) t,
  ];
}

/// Ряды для главной: та же фильтрация плюс выброс полностью опустевших рядов.
///
/// Пустой заголовок над «0 треков» — это враньё интерфейса: либо ряд был
/// полезен и стал пустым после фильтрации (тогда его не показываем), либо
/// движок нечего не дал (тогда нечего звать и заголовком).
List<RecoRow> filterRows(
  Iterable<RecoRow> rows,
  bool Function(String artist) isBlacklisted,
) {
  final out = <RecoRow>[];
  for (final r in rows) {
    final tracks = filterTracks(r.tracks, isBlacklisted);
    if (tracks.isEmpty) continue;
    out.add(RecoRow(r.title, tracks));
  }
  return out;
}

/// Есть ли вообще что послушать: без истории и лайков и волна, и подборки
/// пусты, а «Продолжить слушать» показывать не над чем.
bool hasSomethingToPlay(List<Track> history, List<Track> liked) =>
    history.isNotEmpty || liked.isNotEmpty;

/// Приветствие по времени суток.
///
/// Отдельная чистая функция, а не `DateTime.now()` внутри виджета: приветствие
/// — это текст, который должен проверяться тестом, а не «магия» при сборке.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Доброе утро';
  if (h >= 12 && h < 18) return 'Добрый день';
  if (h >= 18 && h < 23) return 'Добрый вечер';
  return 'Доброй ночи';
}

// ───────────────────────────────── Действия ────────────────────────────────

/// Радио по жанру: ищем в агрегаторе и сразу ставим очередь.
///
/// Снекбар в начале нужен, потому что поиск по нескольким источникам занимает
/// секунды — иначе тап выглядит как «ничего не произошло».
Future<void> startGenreRadio(
  WidgetRef ref,
  BuildContext context,
  String genre,
) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Радио: $genre'), duration: const Duration(seconds: 1)));
  final results =
      await ref.read(aggregatorProvider).search(genre, perSource: 15);
  if (results.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ничего не найдено')));
    }
    return;
  }
  await ref.read(playbackProvider).startRadio(results.first, results);
  ref.read(libraryProvider).pushHistory(results.first);
  if (context.mounted) context.push('/player');
}

/// «Моя волна» — живой поток из движка рекомендаций (профиль + кандидаты +
/// скоринг + anti-repetition). Real-time адаптируется на скип/лайк.
Future<void> startWave(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
      content: Text('Собираю волну…'), duration: Duration(seconds: 1)));
  final engine = ref.read(waveEngineProvider);
  List<Track> buffer;
  try {
    buffer = await engine.start();
  } catch (_) {
    // Движок уже пишет причину в диагностику; пользователю важнее честное
    // «мало данных», чем стектрейс на тост.
    buffer = const [];
  }
  if (buffer.isEmpty) {
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Пока мало данных для волны — '
              'послушайте что-нибудь или уберите дизлайки')));
    }
    return;
  }
  await ref.read(playbackProvider).startRadio(buffer.first, buffer);
  ref.read(libraryProvider).pushHistory(buffer.first);
  if (context.mounted) context.push('/player');
}

/// Pull-to-refresh главной: чистим кэш ленты (иначе aggregator отдаст
/// прошлую выдачу из `_feedTtl`) и пересобираем подборки.
Future<void> refreshHome(WidgetRef ref) async {
  ref.read(aggregatorProvider).clearCache();
  ref.invalidate(recommendationsProvider);
  ref.invalidate(feedProvider);
  await ref.read(feedProvider.future);
}

/// Смена характера волны. Состояние и запись в prefs — одним действием,
/// иначе после перезапуска чипы вернутся к старому значению.
void setWaveMode(WidgetRef ref, WaveMode mode) {
  ref.read(waveModeProvider.notifier).state = mode;
  ref.read(prefsProvider).setString('wave_mode', mode.id);
}

/// Смена настроения волны. См. [setWaveMode] про рассинхрон.
void setWaveMood(WidgetRef ref, WaveMood mood) {
  ref.read(waveMoodProvider.notifier).state = mood;
  ref.read(prefsProvider).setString('wave_mood_tag', mood.id);
}

/// Есть ли ключ Last.fm — то есть работает ли выбор настроения.
bool hasLastfmKey(WidgetRef ref) => ref.read(lastfmServiceProvider).hasApiKey;
