import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../data/sources/youtube_music_source.dart'
    show extractYoutubeVideoId;
import '../../design/icons/app_icons.dart';
import '../../design/widgets/blocks.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';
import '../artist/artist_screen.dart';
import '../common/album_tile.dart';
import '../common/section_tab_bar.dart';
import '../common/skin_controls.dart';
import '../common/skin_tokens.dart';
import '../common/track_row.dart';
import 'search_controller.dart';

/// Поиск по всем включённым источникам.
///
/// Логика (пагинация, недавние запросы, альбомы) живёт в
/// [search_controller.dart]; здесь только вёрстка. Ключевые отличия от
/// прежней версии — не поведение, а форма: поле фильтра и переключатель
/// источников рисуются скином, а подсказки/недавние запросы показываются
/// строками меню, потому что «плашка Material» на монохромном экране выглядела
/// как чужое приложение.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 400) {
      // Догрузку и все гарды (исчерпано/уже грузим/нет данных) держит пагинатор.
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    // Пустая строка или уже вставленная ссылка на видео — автодополнение не нужно.
    if (q.isEmpty || extractYoutubeVideoId(q) != null) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final s = await fetchSearchSuggestions(ref, q);
      if (mounted && _controller.text.trim() == q) {
        setState(() => _suggestions = s);
      }
    });
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    _controller.text = q;
    // Пагинатор сам перезапустится на смену запроса (слушает searchQueryProvider).
    ref.read(searchQueryProvider.notifier).state = q;
    // Сырую ссылку в историю недавних запросов не сохраняем — бесполезна для
    // повторного поиска.
    if (extractYoutubeVideoId(q) == null) {
      ref.read(recentSearchesProvider.notifier).add(q);
    }
    setState(() => _suggestions = const []);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    final search = ref.watch(searchProvider);
    final submitted = ref.watch(searchQueryProvider).trim();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            tokens.space8,
            tokens.space16,
            tokens.space8,
          ),
          child: SkinFilterField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            hint: 'Поиск по всем сервисам',
            onChanged: _onChanged,
            onSubmitted: _submit,
            // Крестик виден всегда, как и раньше: поле не пересобирается на
            // каждый символ, а прятать его по вводу — значит показать с
            // задержкой в один кадр.
            onClear: () {
              _controller.clear();
              ref.read(searchQueryProvider.notifier).state = '';
              setState(() => _suggestions = const []);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space16),
          child: _sourceFilter(),
        ),
        Expanded(child: _body(search, submitted)),
      ],
    );
  }

  /// Ряд источников. Подписи короче [SourceTypeX.shortLabel]: в сегментах
  /// «SoundCloud» не влезает, а «SC» читается так же.
  Widget _sourceFilter() {
    final enabled = ref.watch(settingsProvider).enabledSources;
    final rawFilter = ref.watch(searchFilterProvider);
    final filter =
        rawFilter != null && enabled.contains(rawFilter) ? rawFilter : null;
    const labels = {
      SourceType.youtube: 'YT',
      SourceType.soundcloud: 'SC',
      SourceType.yandex: 'Яндекс',
      SourceType.vk: 'VK',
    };
    final sources = SourceType.values.where(enabled.contains).toList();
    return SectionTabBar(
      labels: ['Все', for (final s in sources) labels[s] ?? s.shortLabel],
      // Индексы совпадают с [sources], потому что «Все» стоит первым.
      index: filter == null ? 0 : sources.indexOf(filter) + 1,
      onChanged: (i) => ref.read(searchFilterProvider.notifier).state =
          i == 0 ? null : sources[i - 1],
    );
  }

  Widget _body(SearchState search, String submitted) {
    final tokens = skinOf(context).tokens;
    // Пока пользователь печатает — показываем живые подсказки.
    if (_suggestions.isNotEmpty) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          for (final s in _suggestions)
            SkinMenuRow(
              title: s,
              leading: AppIcons.search,
              onTap: () => _submit(s),
            ),
        ],
      );
    }

    // Подгрузка следующей порции: держим уже показанный список, а не
    // перекрываем его полноэкранным спиннером на время дозапроса.
    if (search.loadingMore && search.results.hasValue) {
      return _resultsList(search.results.value!, submitted,
          loadingFooter: true);
    }

    return search.results.when(
      loading: () => LoadingBlock(tokens: tokens, lines: 4),
      error: (e, _) => ErrorBlock(
          tokens: tokens, message: 'Ошибка поиска:\n$e', onRetry: null),
      data: (tracks) => _resultsList(tracks, submitted, loadingFooter: false),
    );
  }

  Widget _resultsList(List<Track> tracks, String submitted,
      {required bool loadingFooter}) {
    final tokens = skinOf(context).tokens;
    if (submitted.isEmpty) return _recentsOrHint();
    final albums =
        ref.watch(searchAlbumsProvider).value ?? const <AlbumResult>[];
    if (tracks.isEmpty && albums.isEmpty) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.search,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте другой запрос или другой источник.',
      );
    }
    // Уникальные артисты из результатов (для перехода на их страницы).
    final artists = <String>[];
    final seen = <String>{};
    for (final t in tracks) {
      if (seen.add(t.artist.toLowerCase())) artists.add(t.artist);
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: tracks.length + 1 + (loadingFooter ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (albums.isNotEmpty)
                AlbumStrip(albums: albums.take(20).toList(), header: 'Альбомы'),
              _artistsRow(artists),
            ],
          );
        }
        final idx = i - 1;
        if (idx >= tracks.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.space24),
            child: Center(child: LoadingBlock(tokens: tokens, lines: 1)),
          );
        }
        final t = tracks[idx];
        return Column(
          children: [
            SkinTrackRow(
              track: t,
              onTap: () => playTrack(ref, context, t, queue: tracks),
            ),
            const SkinRowSeparator(),
          ],
        );
      },
    );
  }

  Widget _recentsOrHint() {
    final tokens = skinOf(context).tokens;
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.search,
        title: 'Что послушать?',
        subtitle: 'Введите запрос — найдём по YouTube, SoundCloud и Яндексу '
            'сразу. Либо вставьте ссылку на видео YouTube.',
      );
    }
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            tokens.space12,
            tokens.space12,
            tokens.space4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Недавние запросы',
                  style: tokens.caption.copyWith(color: tokens.textTertiary),
                ),
              ),
              _TextAction(
                label: 'Очистить',
                onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
              ),
            ],
          ),
        ),
        for (final q in recents)
          SkinMenuRow(
            title: q,
            leading: AppIcons.clock,
            onTap: () => _submit(q),
            trailing: SkinIconButton(
              icon: AppIcons.close,
              tooltip: 'Убрать из истории',
              color: tokens.textTertiary,
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).remove(q),
            ),
          ),
      ],
    );
  }

  Widget _artistsRow(List<String> artists) {
    if (artists.isEmpty) return const SizedBox.shrink();
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final list = artists.take(12).toList();
    final chips = [
      for (final a in list)
        _ArtistChip(
          label: a,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ArtistScreen(artist: a)),
          ),
        ),
    ];
    // iPod без горизонтальной ленты: артисты показываются меню-строками.
    if (id.isIpod) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tokens: tokens, title: 'Артисты'),
          for (final a in list)
            SkinMenuRow(
              title: a,
              leading: AppIcons.musicNote,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArtistScreen(artist: a)),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tokens: tokens, title: 'Артисты'),
        SizedBox(
          height: tokens.micro.fontSize! * 2 + tokens.space16 * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: tokens.space16),
            itemCount: chips.length,
            separatorBuilder: (_, __) => SizedBox(width: tokens.space8),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
        const SkinRowSeparator(),
      ],
    );
  }
}

/// Чип артиста: подпись в рамке, тап — страница артиста.
///
/// Свой, а не Material-[ActionChip]: тот приносит свою заливку, радиус и
/// тень, а в iPod-скине это выглядело бы как вклеенный элемент из другой
/// темы. Здесь тот же смысл — «короткая метка, по ней можно перейти».
class _ArtistChip extends StatelessWidget {
  const _ArtistChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    return Center(
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space12,
              vertical: tokens.space8,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(tokens.radiusPill),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.caption.copyWith(color: tokens.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Тихое текстовое действие («Очистить») — без рамки и заливки.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.space8),
          child: Text(
            label,
            style: tokens.caption.copyWith(color: tokens.accent),
          ),
        ),
      ),
    );
  }
}
