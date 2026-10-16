import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/routing/app_router.dart';
import '../../design/icons/app_icons.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/tokens/ipod_tokens.dart';
import '../../domain/models/album_result.dart';
import '../album/album_screen.dart';
import '../common/track_list_screen.dart';
import '../library/library_screen.dart';
import 'home_controller.dart';
import 'track_row_home.dart';
import 'wave_card.dart';

/// Главная iPod-скина — меню, а не лента.
///
/// Пользователь выбрал образ iPod, и меню — его главная черта: девять
/// плиток, ведущих куда угодно, и ни одной ленты, которую пришлось бы
/// прокручивать. Поэтому здесь нет ни ленты источников, ни подборок: вместо
/// них — быстрый доступ к тому, что уже слушали, и к «Моей волне».
class IpodHomeView extends ConsumerWidget {
  const IpodHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outer = SkinScope.maybeOf(context);
    final skin = outer ?? skinFor(SkinId.ipod);
    final tokens = skin.tokens;

    final lib = ref.watch(libraryProvider);
    final history = lib.history;
    final canPlay = hasSomethingToPlay(history, lib.liked);
    final recent = history.take(continueListeningLimit).toList();

    final content = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(tokens.space8),
          sliver: _MenuGrid(
            tokens: tokens,
            onOpen: (item) => _open(context, ref, tokens, item),
          ),
        ),
        // Волна в меню iPod — обычная строка. Показываем её всегда, даже при
        // пустой библиотеке: пункт меню должен вести в то же место, что и
        // всегда, а «мало данных» пользователь и так получит честным ответом
        // движка.
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space8),
            child: WaveCard(onTap: () => startWave(ref, context)),
          ),
        ),
        if (canPlay) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              tokens: tokens,
              title: 'Продолжить слушать',
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space8),
            // Разделитель не добавляем: строка сама рисует его под собой —
            // два разделителя подряд читались бы как двойная линия.
            sliver: SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (_, i) => HomeTrackRow(
                tokens: tokens,
                track: recent[i],
                coverSize: IpodTokens.coverSize,
                onTap: () => playTrack(
                  ref,
                  context,
                  recent[i],
                  queue: recent,
                ),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(child: _NothingToPlay(tokens: tokens)),
        SliverToBoxAdapter(child: SizedBox(height: tokens.space24)),
      ],
    );

    // См. пояснение в IosHomeView: примитивы дизайна берут скин из контекста,
    // а экран обязаны монтировать под оболочкой — страхуем превью и тесты.
    return outer == null ? SkinScope(skin: skin, child: content) : content;
  }
}

/// Пункты главного меню iPod — те самые девять, что были на корпусе.
enum HomeMenuItem {
  playlists,
  artists,
  albums,
  tracks,
  genres,
  favourites,
  downloads,
  stats,
  settings,
}

extension HomeMenuItemX on HomeMenuItem {
  /// Подписи живут здесь, а не в вёрстке: пункт меню — это его имя, и оно
  /// должно читаться одинаково в подсказке, в сортировке и в тесте.
  String get title => switch (this) {
        HomeMenuItem.playlists => 'Плейлисты',
        HomeMenuItem.artists => 'Артисты',
        HomeMenuItem.albums => 'Альбомы',
        HomeMenuItem.tracks => 'Треки',
        HomeMenuItem.genres => 'Жанры',
        HomeMenuItem.favourites => 'Избранное',
        HomeMenuItem.downloads => 'Загрузки',
        HomeMenuItem.stats => 'Статистика',
        HomeMenuItem.settings => 'Настройки',
      };

  AppIconData get icon => switch (this) {
        HomeMenuItem.playlists => AppIcons.queue,
        HomeMenuItem.artists => AppIcons.musicNote,
        HomeMenuItem.albums => AppIcons.library,
        HomeMenuItem.tracks => AppIcons.play,
        HomeMenuItem.genres => AppIcons.search,
        HomeMenuItem.favourites => AppIcons.heartFilled,
        HomeMenuItem.downloads => AppIcons.download,
        HomeMenuItem.stats => AppIcons.stats,
        HomeMenuItem.settings => AppIcons.gear,
      };
}

/// Сетка меню 3×3. Именно 3×3, а не «сколько влезет»: корпус iPod был
/// квадратным, и меню из девяти плиток — его узнаваемый силуэт.
///
/// Сама является слайвером — оборачивать её в [SliverToBoxAdapter] нельзя,
/// адаптер ждёт render box, а сетка рисуется как слайвер.
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.tokens, required this.onOpen});

  final DesignTokens tokens;
  final void Function(HomeMenuItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    const items = HomeMenuItem.values;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: tokens.space8,
        crossAxisSpacing: tokens.space8,
        // Почти квадратная плитка: чуть выше ширины, иначе подпись под иконкой
        // не помещается, а иконка уезжает в угол.
        childAspectRatio: 0.88,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) => _MenuTile(
          tokens: tokens,
          item: items[i],
          onTap: () => onOpen(items[i]),
        ),
        childCount: items.length,
      ),
    );
  }
}

/// Плитка меню: графит, белая иконка в рамке, подпись микро-шрифтом.
///
/// Рамка в 1 px — обязательная часть образа: на графите без неё плитки
/// сливаются в одно поле, и меню перестаёт читаться как сетка пунктов.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.tokens,
    required this.item,
    required this.onTap,
  });

  final DesignTokens tokens;
  final HomeMenuItem item;
  final VoidCallback onTap;

  /// Кегль иконки внутри плитки. Токены его не держат (размер иконки — свойство
  /// пункта меню, а не палитры), поэтому это единственное место, где он задан.
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: tokens.separator, width: 1),
          ),
          // Блик корпуса (showGloss) на девяти плитках выглядел бы как
          // девять маленьких стёкол, поэтому у плитки его нет: графит должен
          // читаться материалом, а не глянцем.
          child: GraphiteBackground(
            base: tokens.surface,
            showGloss: false,
            child: Padding(
              padding: EdgeInsets.all(tokens.space8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: _iconSize * 2,
                    height: _iconSize * 2,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    ),
                    child: AppIcon(
                      item.icon,
                      size: _iconSize,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: tokens.micro.copyWith(color: tokens.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пустое состояние без выдуманной сетки.
///
/// Меню остаётся рабочим (пункты ведут дальше), но показывать «пустую»
/// подборку было бы враньём: слушать нечего, и видеть надо честное «пока
/// нечего слушать» с подсказкой, что делать.
class _NothingToPlay extends StatelessWidget {
  const _NothingToPlay({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space24,
        tokens.space16,
        tokens.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.musicNote,
            size: 28,
            color: tokens.textTertiary,
          ),
          SizedBox(height: tokens.space12),
          Text(
            'Пока нечего слушать',
            style: tokens.headline.copyWith(color: tokens.textSecondary),
          ),
          SizedBox(height: tokens.space4),
          Text(
            'Послушайте что-нибудь из меню выше — и здесь появится '
            'история, а «Моя волна» начнёт подбирать под вас.',
            textAlign: TextAlign.center,
            style: tokens.caption.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Переходы из меню. Один экран — одно место, где решается, куда ведёт
/// пункт: иначе девять плиток разбросают девять `context.push` по экрану.
void _open(
  BuildContext context,
  WidgetRef ref,
  DesignTokens tokens,
  HomeMenuItem item,
) {
  final lib = ref.read(libraryProvider);
  switch (item) {
    case HomeMenuItem.playlists:
      // Экран медиатеки — «тело», а не маршрут: свой Scaffold у него нет,
      // и в маршрут он не выведен. Хостим его здесь, задав фон и отступы.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: tokens.background,
          body: const SafeArea(child: LibraryScreen()),
        ),
      ));
    case HomeMenuItem.artists:
      context.push(Routes.followedArtists);
    case HomeMenuItem.albums:
      showAlbumPicker(context, ref, tokens);
    case HomeMenuItem.tracks:
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TrackListScreen(
          title: 'Треки',
          tracks: lib.history,
        ),
      ));
    case HomeMenuItem.genres:
      showGenrePicker(context, ref, tokens);
    case HomeMenuItem.favourites:
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TrackListScreen(
          title: 'Избранное',
          tracks: lib.liked,
        ),
      ));
    case HomeMenuItem.downloads:
      context.push(Routes.storage);
    case HomeMenuItem.stats:
      context.push(Routes.stats);
    case HomeMenuItem.settings:
      // Настроек в маршрутах нет (см. Routes): внешний вид — единственный
      // экран, который открывается по имени и ведёт в этот раздел.
      context.push(Routes.appearance);
  }
}

/// Лист выбора жанра: тап по жанру сразу запускает радио.
void showGenrePicker(BuildContext context, WidgetRef ref, DesignTokens tokens) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.surface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.space16,
                0,
                tokens.space16,
                tokens.space8,
              ),
              child: Text(
                'Жанры',
                style: tokens.headline.copyWith(color: tokens.textPrimary),
              ),
            ),
            for (final g in homeGenres)
              IpodListRow(
                tokens: tokens,
                title: g,
                onTap: () {
                  // Навигатор листа берём до закрытия: после pop() контекст
                  // листа уже уходит, и следующий запрос контекста бросил бы.
                  final sheet = Navigator.of(sheetContext);
                  sheet.pop();
                  startGenreRadio(ref, context, g);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Лист поиска альбомов.
///
/// Отдельного экрана альбомов в приложении нет, а «Альбомы» без ничего — это
/// пункт, который никуда не ведёт. Поиск идёт через тот же агрегатор, что и
/// остальное, и открывает существующий экран альбома.
void showAlbumPicker(BuildContext context, WidgetRef ref, DesignTokens tokens) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.surface,
    isScrollControlled: true,
    builder: (_) => _AlbumSearchSheet(tokens: tokens),
  );
}

class _AlbumSearchSheet extends ConsumerStatefulWidget {
  const _AlbumSearchSheet({required this.tokens});

  final DesignTokens tokens;

  @override
  ConsumerState<_AlbumSearchSheet> createState() => _AlbumSearchSheetState();
}

class _AlbumSearchSheetState extends ConsumerState<_AlbumSearchSheet> {
  /// Сколько альбомов показываем. Яндекс/YouTube отдают сотни, а экран всё
  /// равно не список из них — а быстрый выбор.
  static const int _limit = 40;

  Future<List<AlbumResult>>? _future;

  void _search(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _future = null);
      return;
    }
    setState(() {
      _future = ref
          .read(aggregatorProvider)
          .searchAlbums(q)
          .then((list) => list.take(_limit).toList())
          // Источник может быть не настроен или сеть лежит: показываем «ничего
          // не нашлось», а не роняем лист с ошибкой в лог.
          .onError((_, __) => const <AlbumResult>[]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final future = _future;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space16,
                  tokens.space16,
                  tokens.space16,
                  tokens.space8,
                ),
                child: TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  onChanged: _search,
                  style: tokens.body.copyWith(color: tokens.textPrimary),
                  cursorColor: tokens.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Название альбома или артиста',
                    hintStyle:
                        tokens.caption.copyWith(color: tokens.textTertiary),
                    prefixIcon: AppIcon(
                      AppIcons.search,
                      size: 18,
                      color: tokens.textTertiary,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.separator),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.accent),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: switch (future) {
                  null => Center(
                      child: Text(
                        'Введите название — поиск идёт по включённым источникам',
                        textAlign: TextAlign.center,
                        style:
                            tokens.caption.copyWith(color: tokens.textTertiary),
                      ),
                    ),
                  _ => FutureBuilder<List<AlbumResult>>(
                      future: future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return LoadingBlock(tokens: tokens);
                        }
                        final albums = snap.data ?? const <AlbumResult>[];
                        if (albums.isEmpty) {
                          return Center(
                            child: Text(
                              'Ничего не нашлось',
                              style: tokens.body
                                  .copyWith(color: tokens.textSecondary),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: albums.length,
                          itemBuilder: (_, i) {
                            final a = albums[i];
                            return IpodListRow(
                              tokens: tokens,
                              title: a.title,
                              subtitle: a.artist,
                              onTap: () {
                                // Оба навигатора берём до закрытия листа:
                                // его контекст после pop() уже недействителен,
                                // а экран альбома должен открыться на корневом.
                                final sheet = Navigator.of(context);
                                final root =
                                    Navigator.of(context, rootNavigator: true);
                                sheet.pop();
                                root.push(MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumScreen(seed: a.toSeedTrack()),
                                ));
                              },
                            );
                          },
                        );
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
