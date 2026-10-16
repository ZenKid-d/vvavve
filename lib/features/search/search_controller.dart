import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod 3 вынес StateProvider/StateNotifier в legacy-модуль (курс на
// Notifier) — см. пояснение в core/providers.dart.
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../data/sources/soundcloud_source.dart';
import '../../data/sources/youtube_music_source.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';

/// Отделённый от экрана мозг поиска.
///
/// Файл существует ради одного свойства: пагинатор держит в состоянии
/// накопленные страницы и переживает пересборку списка, поэтому его нельзя
/// держать в виджете. Когда он лежит рядом с вёрсткой, любая правка UI
/// задевает логику (и наоборот); когда он в своём файле — экран читает
/// провайдеры, а пагинатор ничего не знает про скины и виджеты.

/// Запрос, по которому ищем. Не то, что в поле ввода, а подтверждённое
/// значение: пока пользователь печатает, список результатов остаётся прежним.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Выбранный источник; null — «Все».
final searchFilterProvider = StateProvider<SourceType?>((ref) => null);

/// perSource первой порции у Aggregator.search (режим «Все»).
const baseSearchLimit = 15;

/// Размер «страницы» при фильтре по одному источнику — реальный offset/page
/// самого источника (SoundCloud/VK/Яндекс).
const filteredPageSize = 20;

/// Сколько страниц читать сразу при первом открытии фильтра — стартовая
/// глубина ~40 (2×20).
const initialFilteredPages = 2;

/// Насколько растить perSource режима «Все» за одно долистывание.
const pageStep = 15;

/// Состояние постраничного поиска: текущие результаты + флаги догрузки.
class SearchState {
  const SearchState({
    this.results = const AsyncValue.data(<Track>[]),
    this.loadingMore = false,
    this.exhausted = false,
  });

  final AsyncValue<List<Track>> results;

  /// Идёт догрузка следующей порции (список на экране остаётся, снизу спиннер).
  final bool loadingMore;

  /// Источник(и) больше не отдают новых треков — по скроллу сеть не дёргаем.
  final bool exhausted;

  SearchState copyWith({
    AsyncValue<List<Track>>? results,
    bool? loadingMore,
    bool? exhausted,
  }) =>
      SearchState(
        results: results ?? this.results,
        loadingMore: loadingMore ?? this.loadingMore,
        exhausted: exhausted ?? this.exhausted,
      );
}

/// Инкрементальный пагинатор поиска. Копит уже полученные страницы и при
/// долистывании догружает ТОЛЬКО следующую (без перезапроса всех 0..N), дедуп
/// по uid. Перезапускается при смене запроса/фильтра/набора источников.
final searchProvider =
    StateNotifierProvider.autoDispose<SearchPager, SearchState>(
        (ref) => SearchPager(ref));

/// Поиск альбомов по submitted-запросу (не пагинируется — короткая выдача).
/// Нативно умеют только YouTube Music и SoundCloud, поэтому при фильтре на
/// Яндекс/VK альбомы не ищем (пустой результат без похода в сеть).
final searchAlbumsProvider =
    FutureProvider.autoDispose<List<AlbumResult>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty || extractYoutubeVideoId(q) != null) return const [];
  final enabled = ref.watch(settingsProvider).enabledSources;
  final rawFilter = ref.watch(searchFilterProvider);
  final filter =
      (rawFilter != null && enabled.contains(rawFilter)) ? rawFilter : null;
  if (filter != null &&
      filter != SourceType.youtube &&
      filter != SourceType.soundcloud) {
    return const [];
  }
  final aggregator = ref.read(aggregatorProvider);
  if (filter == SourceType.youtube) {
    final src = aggregator.sourceFor(SourceType.youtube);
    return src is YoutubeMusicSource ? src.searchAlbums(q) : const [];
  }
  if (filter == SourceType.soundcloud) {
    final src = aggregator.sourceFor(SourceType.soundcloud);
    return src is SoundcloudSource ? src.searchAlbums(q) : const [];
  }
  return aggregator.searchAlbums(q);
});

/// История поиска (последние запросы), хранится в SharedPreferences.
final recentSearchesProvider =
    StateNotifierProvider<RecentSearches, List<String>>(
        (ref) => RecentSearches(ref.read(prefsProvider)));

class SearchPager extends StateNotifier<SearchState> {
  SearchPager(this._ref) : super(const SearchState()) {
    _enabled = _ref.read(settingsProvider).enabledSources.toSet();
    _ref.listen(searchQueryProvider, (_, __) => _restart(),
        fireImmediately: true);
    _ref.listen(searchFilterProvider, (_, __) => _restart());
    // Набор включённых источников влияет и на эффективный фильтр, и на «Все».
    // Перезапускаем только когда реально изменился состав (settingsProvider
    // шлёт уведомления и по не связанным с источниками настройкам).
    _ref.listen(settingsProvider, (_, next) {
      final now = next.enabledSources;
      if (now.length != _enabled.length || !now.containsAll(_enabled)) {
        _enabled = now.toSet();
        _restart();
      }
    });
  }

  final Ref _ref;
  Set<SourceType> _enabled = const {};

  // Аккумулятор текущего запроса. _token отсекает результаты устаревших
  // запросов (пользователь сменил запрос, пока летел ответ).
  int _token = 0;
  final List<Track> _items = [];
  final Set<String> _seen = {};
  int _nextPage = 0;

  SourceType? get _effectiveFilter {
    final raw = _ref.read(searchFilterProvider);
    // Источник могли выключить, пока был выбран его фильтр — ведём как «Все».
    return (raw != null &&
            _ref.read(settingsProvider).enabledSources.contains(raw))
        ? raw
        : null;
  }

  Future<void> _restart() async {
    final token = ++_token;
    _items.clear();
    _seen.clear();
    _nextPage = 0;
    final q = _ref.read(searchQueryProvider).trim();
    if (q.isEmpty) {
      state = const SearchState();
      return;
    }
    // Вставленная ссылка на видео YouTube — резолвим ровно это видео.
    final videoId = extractYoutubeVideoId(q);
    if (videoId != null) {
      await _resolveDirect(token, videoId);
      return;
    }
    state = const SearchState(results: AsyncValue.loading());
    final initial =
        _effectiveFilter != null ? initialFilteredPages : 1; // «Все» — 1 порция
    await _fetchMore(token, initial);
  }

  Future<void> _resolveDirect(int token, String videoId) async {
    // Прямую ссылку открываем, только если YouTube включён — иначе играли бы
    // через отключённый пользователем источник.
    if (!_ref
        .read(settingsProvider)
        .enabledSources
        .contains(SourceType.youtube)) {
      state = SearchState(
        results: AsyncValue.error(
          'Включите YouTube в настройках, чтобы открывать ссылки на видео.',
          StackTrace.current,
        ),
        exhausted: true,
      );
      return;
    }
    state = const SearchState(results: AsyncValue.loading());
    try {
      final t = await _ref.read(youtubeSourceProvider).resolveVideo(videoId);
      if (token != _token) return;
      _items.add(t);
      _seen.add(t.uid);
      state = SearchState(
          results: AsyncValue.data(List.of(_items)), exhausted: true);
    } catch (e, st) {
      if (token != _token) return;
      state = SearchState(results: AsyncValue.error(e, st), exhausted: true);
    }
  }

  /// Догрузка следующей порции (вызывается при долистывании до конца).
  void loadMore() {
    if (state.loadingMore || state.exhausted) return;
    if (state.results is! AsyncData) return;
    state = state.copyWith(loadingMore: true);
    _fetchMore(_token, 1);
  }

  Future<void> _fetchMore(int token, int pages) async {
    final q = _ref.read(searchQueryProvider).trim();
    final filter = _effectiveFilter;
    try {
      for (var i = 0; i < pages; i++) {
        final page = await _fetchPage(q, filter, _nextPage);
        if (token != _token) return;
        _nextPage++;
        var added = 0;
        for (final t in page) {
          if (_seen.add(t.uid)) {
            _items.add(t);
            added++;
          }
        }
        // Ничего нового (источник без пагинации / выдал только дубли / пусто) —
        // дальше по скроллу не тянем.
        if (added == 0) {
          state = SearchState(
              results: AsyncValue.data(List.of(_items)), exhausted: true);
          return;
        }
      }
      state = SearchState(results: AsyncValue.data(List.of(_items)));
    } catch (e, st) {
      if (token != _token) return;
      // Ошибку показываем, только если совсем ничего нет; иначе оставляем уже
      // загруженное и НЕ помечаем exhausted — сбой мог быть транзиентным.
      state = _items.isEmpty
          ? SearchState(results: AsyncValue.error(e, st))
          : SearchState(results: AsyncValue.data(List.of(_items)));
    }
  }

  Future<List<Track>> _fetchPage(String q, SourceType? filter, int page) {
    final aggregator = _ref.read(aggregatorProvider);
    if (filter != null) {
      final source = aggregator.sourceFor(filter);
      // Источник без пагинации на page > 0 вернул бы ту же первую страницу —
      // не ходим в сеть, пусть вызывающий пометит exhausted (added == 0).
      if (page > 0 && !source.supportsPaging) return Future.value(const []);
      return source.search(q, limit: filteredPageSize, page: page);
    }
    // «Все»: у агрегатора нет постраничности — растим perSource, дедуп в
    // [_fetchMore] оставит только новые треки.
    return aggregator.search(q, perSource: baseSearchLimit + page * pageStep);
  }
}

/// Недавние запросы: список строк в SharedPreferences.
class RecentSearches extends StateNotifier<List<String>> {
  RecentSearches(this._prefs)
      : super(_prefs.getStringList('recent_searches') ?? const []);
  final SharedPreferences _prefs;

  void add(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    final list = [
      q,
      ...state.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(12).toList();
    state = list;
    _prefs.setStringList('recent_searches', list);
  }

  void remove(String q) {
    final list = state.where((e) => e != q).toList();
    state = list;
    _prefs.setStringList('recent_searches', list);
  }

  void clear() {
    state = const [];
    _prefs.setStringList('recent_searches', const []);
  }
}

/// Живые подсказки из автодополнения Google/YouTube.
///
/// Отдельная функция, а не метод виджета: запрос уходит по сети, и держать
/// такие вещи в State виджета — значит забыть про них при dispose.
Future<List<String>> fetchSearchSuggestions(WidgetRef ref, String q) async {
  try {
    final r = await ref.read(dioProvider).get<String>(
          'https://suggestqueries.google.com/complete/search',
          queryParameters: {'client': 'firefox', 'ds': 'yt', 'q': q},
          options: Options(responseType: ResponseType.plain),
        );
    final data = jsonDecode(r.data ?? '[]');
    final list = (data is List && data.length > 1) ? data[1] as List : const [];
    return list.map((e) => e.toString()).take(8).toList();
  } catch (_) {
    return const [];
  }
}
