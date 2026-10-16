import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/io/file_io.dart';
import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/widgets/mini_player.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import '../common/album_tile.dart';
import '../common/section_tab_bar.dart';
import '../common/skin_controls.dart';
import '../common/skin_tokens.dart';
import '../common/track_list_screen.dart';
import '../common/track_row.dart';
import 'library_controller.dart';

/// Медиатека: плейлисты, любимое, загрузки и очередь.
///
/// Экран намеренно «глупый»: фильтрация, сортировка и умные подборки живут в
/// [library_controller.dart], импорт — в [LibraryActions]. Здесь только
/// вёрстка, и она единственная, кто решает, как выглядит список в iOS- и
/// iPod-скине. Поэтому здесь нет ни одного `Icons.*` и ни одного цвета из
/// палитры Material: только токены скина и [AppIcon].
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.playlists;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectTab(LibraryTab tab) {
    setState(() => _tab = tab);
    // Фильтр принадлежит вкладке: оставшийся от «Плейлистов» текст в
    // «Загрузках» отсеял бы всё, и пользователь считал бы, что загрузок нет.
    _search.clear();
    ref.read(libraryQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final query = ref.watch(libraryQueryProvider);

    return Column(
      children: [
        _toolbar(tokens, id.isIpod),
        if (_tab != LibraryTab.queue)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space16,
              0,
              tokens.space16,
              tokens.space8,
            ),
            child: SkinFilterField(
              controller: _search,
              hint: _tab == LibraryTab.playlists
                  ? 'Фильтр плейлистов'
                  : 'Фильтр по названию или артисту',
              onChanged: (v) => ref.read(libraryQueryProvider.notifier).state =
                  v.trim().toLowerCase(),
              onClear: query.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      ref.read(libraryQueryProvider.notifier).state = '';
                    },
            ),
          ),
        Expanded(child: _bodyFor(_tab)),
      ],
    );
  }

  /// Шапка: вкладки и действия.
  ///
  /// На iPod сегменты занимают всю ширину, а действия уходят на отдельную
  /// строку: корпус iPod был узким, и три кнопки рядом с четырьмя сегментами
  /// превратились бы в нечитаемую полосу.
  Widget _toolbar(DesignTokens tokens, bool ipod) {
    final tabs = SectionTabBar(
      labels: libraryTabs,
      index: _tab.index,
      onChanged: (i) => _selectTab(LibraryTab.values[i]),
      scrollable: !ipod,
    );
    final actions = _actions(tokens);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space8,
        tokens.space8,
        tokens.space8,
        tokens.space4,
      ),
      child: ipod
          ? Column(
              children: [tabs, SizedBox(height: tokens.space4), actions],
            )
          : Row(
              children: [
                Expanded(child: tabs),
                SizedBox(width: tokens.space8),
                actions,
              ],
            ),
    );
  }

  Widget _actions(DesignTokens tokens) => switch (_tab) {
        LibraryTab.playlists => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkinIconButton(
                icon: AppIcons.stats,
                tooltip: 'Сортировка',
                color: tokens.textSecondary,
                onPressed: _showSort,
              ),
              SkinIconButton(
                icon: AppIcons.download,
                tooltip: 'Импорт плейлиста',
                onPressed: _import,
              ),
              SkinIconButton(
                icon: AppIcons.plus,
                tooltip: 'Новый плейлист',
                onPressed: _createPlaylist,
              ),
            ],
          ),
        LibraryTab.liked => SkinIconButton(
            icon: AppIcons.download,
            tooltip: 'Скачать все лайки',
            onPressed: () async =>
                _snack(await LibraryActions(ref).downloadLiked()),
          ),
        LibraryTab.downloads || LibraryTab.queue => const SizedBox.shrink(),
      };

  Widget _bodyFor(LibraryTab t) => switch (t) {
        LibraryTab.playlists => const _PlaylistsView(),
        LibraryTab.liked => const _LikedView(),
        LibraryTab.downloads => const _DownloadsView(),
        LibraryTab.queue => const _QueueView(),
      };

  Future<void> _createPlaylist() async {
    final name = await _askName(context, 'Новый плейлист');
    if (name != null && name.isNotEmpty) {
      await ref.read(libraryProvider).createPlaylist(name);
    }
  }

  /// Сортировка плейлистов. Раньше это был [PopupMenuButton], но он рисует
  /// Material-меню со своей рамкой и радиусами — в iPod-скине это выглядело
  /// как чужое окно поверх чёрного экрана.
  void _showSort() {
    final tokens = skinOf(context).tokens;
    final current = ref.read(playlistSortProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Сортировка', tokens),
            for (final e in playlistSortLabels.entries)
              SkinMenuRow(
                title: e.value,
                leading:
                    e.key == current ? AppIcons.check : AppIcons.chevronRight,
                selected: e.key == current,
                onTap: () {
                  ref.read(playlistSortProvider.notifier).state = e.key;
                  Navigator.pop(sheetCtx);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// null — показывать нечего (операция отменена или прошла штатно).
  void _snack(String? msg) {
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showLoading() {
    final tokens = skinOf(context).tokens;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        // Ширину задаём явно: диалог без детей фиксированной ширины
        // схлопывается до полосы заглушки.
        child: SizedBox(
          width: 160,
          height: 96,
          child: LoadingBlock(tokens: tokens, lines: 2),
        ),
      ),
    );
  }

  /// Прячет индикатор загрузки. Отдельный метод, потому что во всех ветках
  /// импорта («поймали ошибку», «ничего не нашли», «сохранили») заглушка должна
  /// закрываться одинаково — забытый pop оставлял бы её навсегда.
  void _hideLoading() {
    if (mounted) Navigator.pop(context); // индикатор
  }

  /// Импорт. Диалоги ввода и списки выбора остаются здесь (это чистый UI),
  /// а сама операция — в [LibraryActions]: по нажатию кнопки «Импорт» экран
  /// только спрашивает, откуда, и показывает то, что вернул контроллер.
  Future<void> _import() async {
    final tokens = skinOf(context).tokens;
    final src = await showModalBottomSheet<PlaylistImportSource>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Импорт плейлиста', tokens),
            SkinMenuRow(
              title: 'Из YouTube (ссылка)',
              leading: AppIcons.play,
              onTap: () =>
                  Navigator.pop(sheetCtx, PlaylistImportSource.youtube),
            ),
            SkinMenuRow(
              title: 'Лайки YouTube Music (вход Google)',
              leading: AppIcons.heart,
              onTap: () =>
                  Navigator.pop(sheetCtx, PlaylistImportSource.youtubeLikes),
            ),
            SkinMenuRow(
              title: 'Из Яндекса (мои плейлисты)',
              leading: AppIcons.musicNote,
              onTap: () => Navigator.pop(sheetCtx, PlaylistImportSource.yandex),
            ),
            SkinMenuRow(
              title: 'Из Spotify (ссылка)',
              subtitle: 'Плейлист/альбом → играем из свободных источников',
              leading: AppIcons.radio,
              onTap: () =>
                  Navigator.pop(sheetCtx, PlaylistImportSource.spotify),
            ),
            SkinMenuRow(
              title: 'Из списка (текст)',
              subtitle: '«Артист — Трек» построчно',
              leading: AppIcons.queue,
              onTap: () => Navigator.pop(sheetCtx, PlaylistImportSource.list),
            ),
            SkinMenuRow(
              title: 'Из файла (.json)',
              leading: AppIcons.storage,
              onTap: () => Navigator.pop(sheetCtx, PlaylistImportSource.file),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    switch (src) {
      case PlaylistImportSource.youtube:
        await _importYoutube();
      case PlaylistImportSource.youtubeLikes:
        await _importYoutubeLikes();
      case PlaylistImportSource.yandex:
        await _importYandex();
      case PlaylistImportSource.spotify:
        await _importSpotify();
      case PlaylistImportSource.file:
        await _importPlaylistFile();
      case PlaylistImportSource.list:
        await _importFromList();
    }
  }

  Future<void> _importSpotify() async {
    final url = await _askText(
      context,
      'Импорт из Spotify',
      'https://open.spotify.com/playlist/…',
      'Импорт',
    );
    if (url == null || url.trim().isEmpty) return;
    _showLoading();
    String? message;
    try {
      message = await LibraryActions(ref).importFromSpotify(url);
    } finally {
      _hideLoading();
    }
    _snack(message);
  }

  Future<void> _importFromList() async {
    final text = await _askText(
      context,
      'Импорт по списку',
      'Eminem — Lose Yourself\nThe Weeknd — Blinding Lights\n…',
      'Найти',
      maxLines: 8,
    );
    if (text == null || text.trim().isEmpty) return;
    _showLoading();
    late final ImportResult<MatchedTracks> res;
    try {
      res = await LibraryActions(ref).matchTextList(text);
    } finally {
      _hideLoading();
    }
    final found = res.value;
    if (found == null) {
      _snack(res.message);
      return;
    }
    // Имя спрашиваем только когда уже что-то нашлось — иначе пользователь
    // назовёт плейлист впустую.
    if (!mounted) return;
    final name =
        await _askName(context, 'Название плейлиста', initial: 'Мой список');
    if (name != null && name.isNotEmpty) {
      _snack(await LibraryActions(ref).saveTextList(found, name));
    }
  }

  Future<void> _importPlaylistFile() async {
    // Выбор файла — системный диалог, его показывает экран; разбор и
    // сохранение — уже в контроллере.
    final content = await pickJsonText();
    if (content == null) return;
    _snack(await LibraryActions(ref).importPlaylistJson(content));
  }

  Future<void> _importYoutubeLikes() async {
    _showLoading();
    late final ImportResult<List<Track>> res;
    try {
      res = await LibraryActions(ref).fetchYoutubeLikes();
    } finally {
      _hideLoading();
    }
    final tracks = res.value;
    if (tracks == null) {
      _snack(res.message);
      return;
    }
    if (!mounted) return;
    final tokens = skinOf(context).tokens;
    final choice = await showDialog<YoutubeLikesTarget>(
      context: context,
      builder: (dialogCtx) => _SkinDialog(
        tokens: tokens,
        title: 'Куда добавить лайки?',
        subtitle: 'Найдено треков: ${tracks.length}',
        actions: [
          (
            'Отдельным плейлистом',
            () => Navigator.pop(dialogCtx, YoutubeLikesTarget.playlist)
          ),
          (
            'В «Избранное»',
            () => Navigator.pop(dialogCtx, YoutubeLikesTarget.liked)
          ),
        ],
      ),
    );
    if (choice != null) {
      _snack(await LibraryActions(ref).saveYoutubeLikes(tracks, choice));
    }
  }

  Future<void> _importYoutube() async {
    final url = await _askName(context, 'Ссылка на плейлист YouTube');
    if (url == null || url.isEmpty) return;
    _showLoading();
    String? message;
    try {
      message = await LibraryActions(ref).importFromYoutube(url);
    } finally {
      _hideLoading();
    }
    _snack(message);
  }

  Future<void> _importYandex() async {
    final actions = LibraryActions(ref);
    // Спрашиваем про токен ДО «крутилки»: импортировать всё равно нечем.
    final missing = actions.missingYandexToken;
    if (missing != null) {
      _snack(missing);
      return;
    }
    _showLoading();
    late final ImportResult<List<YandexPlaylist>> res;
    try {
      res = await actions.fetchYandexPlaylists();
    } finally {
      _hideLoading();
    }
    final pls = res.value;
    if (pls == null) {
      _snack(res.message);
      return;
    }
    if (!mounted) return;
    final tokens = skinOf(context).tokens;
    final picked = await showModalBottomSheet<YandexPlaylist>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _sheetTitle('Выберите плейлист', tokens),
            for (final p in pls)
              SkinMenuRow(
                title: p.title,
                subtitle: '${p.count} треков',
                onTap: () => Navigator.pop(sheetCtx, p),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _showLoading();
    String? message;
    try {
      message = await actions.importYandexPlaylist(picked);
    } finally {
      _hideLoading();
    }
    _snack(message);
  }
}

/// Заголовок bottom-sheet в токенах скина.
Widget _sheetTitle(String title, DesignTokens tokens) => Padding(
      padding: EdgeInsets.all(tokens.space16),
      child: Text(
        title,
        style: tokens.headline.copyWith(color: tokens.textSecondary),
      ),
    );

/// Диалог ввода строки. Имя и ссылка, и список треков запрашиваются одним
/// виджетом — иначе в проекте было бы шесть почти одинаковых диалогов.
Future<String?> _askName(BuildContext context, String title,
        {String initial = ''}) =>
    _askText(context, title, 'Название', 'Сохранить', initial: initial);

Future<String?> _askText(
  BuildContext context,
  String title,
  String hint,
  String actionLabel, {
  String initial = '',
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initial);
  final tokens = skinOf(context).tokens;
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => _SkinDialog(
      tokens: tokens,
      title: title,
      field: SkinFilterField(
        controller: controller,
        hint: hint,
        autofocus: true,
        onChanged: (_) {},
        maxLines: maxLines,
        onSubmitted: (v) => Navigator.pop(dialogCtx, controller.text.trim()),
      ),
      actions: [
        ('Отмена', () => Navigator.pop(dialogCtx)),
        (actionLabel, () => Navigator.pop(dialogCtx, controller.text.trim())),
      ],
      maxLines: maxLines,
    ),
  );
}

/// Диалог скина: заголовок, необязательное пояснение/поле и ряд кнопок.
///
/// Заменяет [AlertDialog]: тот рисует Material-«карточку» с собственными
/// радиусами и типографикой, а в монохромном iPod это был самый заметный
/// чужой элемент на экране.
class _SkinDialog extends StatelessWidget {
  const _SkinDialog({
    required this.tokens,
    required this.title,
    this.subtitle,
    this.field,
    this.actions = const [],
    this.maxLines = 1,
  });

  final DesignTokens tokens;
  final String title;
  final String? subtitle;
  final Widget? field;

  /// Пары «подпись — действие», выполняются по нажатию.
  final List<(String, VoidCallback)> actions;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tokens.headline.copyWith(color: tokens.textPrimary),
            ),
            if (subtitle != null) ...[
              SizedBox(height: tokens.space4),
              Text(
                subtitle,
                style: tokens.caption.copyWith(color: tokens.textSecondary),
              ),
            ],
            if (field != null) ...[
              SizedBox(height: tokens.space12),
              field!,
            ],
            SizedBox(height: tokens.space8),
            // Кнопки в ряд: на узком экране iPod столбик растягивал бы
            // диалог на пол-экрана ради двух слов.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final (label, onTap) in actions)
                  Padding(
                    padding: EdgeInsets.only(left: tokens.space8),
                    child: SkinActionButton(label: label, onPressed: onTap),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Плейлисты: умные подборки сверху, потом пользовательские.
class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    final lib = ref.watch(libraryProvider);
    final q = ref.watch(libraryQueryProvider);
    final sort = ref.watch(playlistSortProvider);
    final playlists = sortPlaylists(
      lib.playlists
          .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
          .toList(),
      sort,
    );
    final smart = buildSmartPlaylists(lib, q)
        // Пустые подборки не показываем: «Только лайки: 0 треков» — шум, а не
        // информация. Отсекаем здесь, чтобы разделитель не повис над пустым
        // списком плейлистов.
        .where((s) => s.tracks.isNotEmpty)
        .toList();

    return ListView(
      children: [
        for (final s in smart)
          SkinMenuRow(
            title: s.title,
            subtitle: '${s.tracks.length} треков · авто',
            leading: _smartIcon(s.kind),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  TrackListScreen(title: s.title, tracks: s.tracks),
            )),
          ),
        if (smart.isNotEmpty) const SkinRowSeparator(),
        if (playlists.isEmpty)
          EmptyState(
            tokens: tokens,
            icon: AppIcons.library,
            title: q.isEmpty ? 'Плейлистов пока нет' : 'Ничего не найдено',
            subtitle: q.isEmpty
                ? 'Нажмите «+», чтобы создать свой, или импортируйте готовый.'
                : 'Попробуйте другое слово фильтра.',
          )
        else
          for (final pl in playlists)
            SkinAlbumTile(
              compact: true,
              title: pl.name,
              artist: '${pl.tracks.length} треков',
              subtitle: _createdAtLabel(pl.id),
              artworkUrl: pl.cover?.artworkUrl,
              seed: pl.id,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlaylistScreen(playlistId: pl.id),
              )),
              trailing: SkinIconButton(
                icon: AppIcons.more,
                tooltip: 'Действия с плейлистом',
                color: tokens.textTertiary,
                onPressed: () => _playlistMenu(context, ref, pl),
              ),
            ),
      ],
    );
  }

  /// Подпись «добавлен 12.03.24»: дата зашита в id плейлиста — единственное
  /// место, где она есть, а сортировка «недавно добавленные» без неё выглядит
  /// враньём. Старые id без даты просто остаются без подписи.
  static String? _createdAtLabel(String id) {
    final ms = playlistCreatedAt(id);
    if (ms <= 0) return null;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return 'добавлен ${d.day}.${d.month}.${d.year}';
  }

  void _playlistMenu(BuildContext context, WidgetRef ref, PlaylistX pl) {
    final tokens = skinOf(context).tokens;
    final actions = LibraryActions(ref);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle(pl.name, tokens),
            SkinMenuRow(
              title: 'Переименовать',
              leading: AppIcons.more,
              onTap: () async {
                Navigator.pop(sheetCtx);
                final name =
                    await _askName(context, 'Переименовать', initial: pl.name);
                if (name != null && name.isNotEmpty) {
                  await ref.read(libraryProvider).renamePlaylist(pl.id, name);
                }
              },
            ),
            SkinMenuRow(
              title: 'Убрать дубликаты',
              leading: AppIcons.sync,
              onTap: () async {
                Navigator.pop(sheetCtx);
                final msg = await actions.removeDuplicates(pl.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
            SkinMenuRow(
              title: 'Экспорт в файл',
              leading: AppIcons.share,
              onTap: () {
                Navigator.pop(sheetCtx);
                actions.exportPlaylist(pl);
              },
            ),
            SkinMenuRow(
              title: 'Удалить',
              leading: AppIcons.delete,
              onTap: () {
                ref.read(libraryProvider).deletePlaylist(pl.id);
                Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Иконки умных подборок — всё, что от них осталось в UI. Сами списки
/// считает [buildSmartPlaylists], чтобы логика не жила в вёрстке.
AppIconData _smartIcon(SmartPlaylistKind kind) => switch (kind) {
      SmartPlaylistKind.top => AppIcons.stats,
      SmartPlaylistKind.recent => AppIcons.clock,
      SmartPlaylistKind.liked => AppIcons.heartFilled,
    };

/// Любимое: альбомы (подборка) и треки.
class _LikedView extends ConsumerWidget {
  const _LikedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    final q = ref.watch(libraryQueryProvider);
    final lib = ref.watch(libraryProvider);
    final liked = lib.liked.where((t) => matchTrack(t, q)).toList();
    final likedAlbums = lib.likedAlbums.where((a) => matchAlbum(a, q)).toList();

    if (liked.isEmpty && likedAlbums.isEmpty) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.heart,
        title: q.isEmpty ? 'Нет лайкнутых треков' : 'Ничего не найдено',
        subtitle: q.isEmpty
            ? 'Лайкнутые треки и альбомы появятся здесь.'
            : 'Попробуйте другое слово фильтра.',
      );
    }

    // Альбомы — общей секцией сверху: они «объёмнее» трека, и в iPod-скине их
    // удобнее читать списком, чем горизонтальной лентой с прокруткой вбок.
    final albumsBlock = likedAlbums.isEmpty
        ? null
        : AlbumStrip(albums: likedAlbums, header: 'Альбомы');

    return ListView.builder(
      itemCount: liked.length + (albumsBlock == null ? 0 : 1),
      itemBuilder: (_, i) {
        if (i == 0 && albumsBlock != null) return albumsBlock;
        final idx = i - (albumsBlock == null ? 0 : 1);
        final t = liked[idx];
        return Column(
          children: [
            SkinTrackRow(
              track: t,
              onTap: () => playTrack(ref, context, t, queue: liked),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkinDownloadStatus(t),
                  SkinIconButton(
                    icon: AppIcons.heartFilled,
                    tooltip: 'Убрать из избранного',
                    color: tokens.accent,
                    onPressed: () => ref.read(libraryProvider).toggleLike(t),
                  ),
                ],
              ),
            ),
            const SkinRowSeparator(),
          ],
        );
      },
    );
  }
}

/// Загрузки: прогресс плейлиста, кольца по трекам и удаление.
class _DownloadsView extends ConsumerWidget {
  const _DownloadsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    final ctl = ref.watch(downloadsProvider);
    final q = ref.watch(libraryQueryProvider);
    // Недавно скачанные — сверху.
    final dl = ctl.downloads.reversed.where((t) => matchTrack(t, q)).toList();
    final busy = ctl.inProgress.where((t) => matchTrack(t, q)).toList();

    if (dl.isEmpty && busy.isEmpty && !ctl.playlistBusy) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.storage,
        title: q.isEmpty ? 'Нет скачанных треков' : 'Ничего не найдено',
        subtitle: q.isEmpty
            ? 'Скачанные файлы живут на устройстве и играют без сети.'
            : 'Попробуйте другое слово фильтра.',
      );
    }

    // Список скачанных строим лениво (SliverList) — при большой библиотеке
    // не создаём сотни строк с картинками разом.
    return CustomScrollView(
      slivers: [
        if (ctl.playlistBusy)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.space16,
                tokens.space12,
                tokens.space16,
                tokens.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Скачивается плейлист: ${ctl.playlistName} · '
                    '${(ctl.playlistProgress * 100).round()}%',
                    style: tokens.caption.copyWith(color: tokens.textSecondary),
                  ),
                  SizedBox(height: tokens.space8),
                  SkinProgressBar(value: ctl.playlistProgress),
                ],
              ),
            ),
          ),
        if (busy.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final t = busy[i];
                return SkinTrackRow(
                  track: t,
                  onTap: () => playTrack(ref, context, t, queue: busy),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(ctl.progressFor(t.uid) * 100).round()}%',
                        style:
                            tokens.micro.copyWith(color: tokens.textSecondary),
                      ),
                      SkinRingProgress(
                        value: ctl.progressFor(t.uid),
                        size: 22,
                        indeterminate: ctl.progressFor(t.uid) == 0,
                      ),
                    ],
                  ),
                );
              },
              childCount: busy.length,
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final t = dl[i];
              return SkinTrackRow(
                track: t,
                onTap: () => playTrack(ref, context, t, queue: dl),
                trailing: SkinIconButton(
                  icon: AppIcons.delete,
                  tooltip: 'Удалить файл',
                  color: tokens.textTertiary,
                  onPressed: () => ref.read(downloadsProvider).remove(t.uid),
                ),
              );
            },
            childCount: dl.length,
          ),
        ),
      ],
    );
  }
}

/// Очередь: перетаскивание и сохранение как плейлиста.
class _QueueView extends ConsumerWidget {
  const _QueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    final pc = ref.watch(playbackProvider);
    final queue = pc.queue;
    if (queue.isEmpty) {
      return EmptyState(
        tokens: tokens,
        icon: AppIcons.queue,
        title: 'Очередь пуста',
        subtitle: 'Запустите альбом или плейлист — треки встанут в очередь.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            tokens.space4,
            tokens.space16,
            tokens.space8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkinActionButton(
              label: 'Сохранить очередь как плейлист',
              icon: AppIcons.plus,
              onPressed: () async {
                final name = await _askName(context, 'Новый плейлист',
                    initial: 'Очередь');
                if (name != null && name.isNotEmpty) {
                  final msg = await LibraryActions(ref)
                      .saveQueueAsPlaylist(name, queue);
                  if (context.mounted && msg != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                }
              },
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: queue.length,
            onReorderItem: pc.reorderQueue,
            // Ручка перетаскивания живёт в конце строки, поэтому стандартные
            // «долгие тапы по всей строке» выключены: иначе они конфликтуют с
            // контекстным меню трека по долгому тапу.
            buildDefaultDragHandles: false,
            itemBuilder: (_, i) {
              final t = queue[i];
              return SkinTrackRow(
                key: ValueKey(t.uid),
                track: t,
                active: t.uid == pc.current?.uid,
                onTap: () =>
                    playTrack(ref, context, t, queue: queue, openPlayer: false),
                trailing: ReorderableDelayedDragStartListener(
                  index: i,
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space8),
                    child: AppIcon(
                      AppIcons.queue,
                      size: 20,
                      color: tokens.textTertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Экран одного плейлиста: треки, фильтр, скачивание, удаление из плейлиста.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    final pl = ref.watch(libraryProvider).playlists.firstWhere(
        (e) => e.id == widget.playlistId,
        orElse: () => PlaylistX(id: widget.playlistId, name: 'Плейлист'));
    final downloads = ref.watch(downloadsProvider);
    final tracks = pl.tracks.where((t) => matchTrack(t, _q)).toList();

    return Scaffold(
      backgroundColor: tokens.background,
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: Column(
        children: [
          // Своя «шапка» вместо AppBar: у оболочки скина своя, а Material-AppBar
          // притащил бы за собой тему, ради которой всё и затевалось.
          SizedBox(
            height: 56,
            child: Row(
              children: [
                SkinIconButton(
                  icon: AppIcons.back,
                  tooltip: 'Назад',
                  color: tokens.accent,
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Text(
                    pl.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.title.copyWith(color: tokens.textPrimary),
                  ),
                ),
                SkinIconButton(
                  icon: AppIcons.download,
                  tooltip: 'Скачать плейлист',
                  onPressed: (pl.tracks.isEmpty || downloads.playlistBusy)
                      ? null
                      : () => ref
                          .read(downloadsProvider)
                          .downloadPlaylist(pl.name, pl.tracks),
                ),
              ],
            ),
          ),
          if (downloads.playlistBusy)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space16),
              child: SkinProgressBar(value: downloads.playlistProgress),
            ),
          if (pl.tracks.isEmpty)
            Expanded(
              child: EmptyState(
                tokens: tokens,
                icon: AppIcons.library,
                title: 'Плейлист пуст',
                subtitle: 'Добавьте треки долгим тапом в любом списке.',
              ),
            )
          else ...[
            if (pl.tracks.length >= 8)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space16,
                  tokens.space8,
                  tokens.space16,
                  tokens.space8,
                ),
                child: SkinFilterField(
                  controller: _search,
                  hint: 'Поиск в плейлисте',
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  onClear: _q.isEmpty
                      ? null
                      : () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                ),
              ),
            Expanded(
              child: tracks.isEmpty
                  ? EmptyState(
                      tokens: tokens,
                      icon: AppIcons.search,
                      title: 'Ничего не найдено',
                      subtitle: 'Попробуйте другое слово фильтра.',
                    )
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final t = tracks[i];
                        return Column(
                          children: [
                            SkinTrackRow(
                              track: t,
                              onTap: () =>
                                  playTrack(ref, context, t, queue: tracks),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SkinDownloadStatus(t),
                                  SkinIconButton(
                                    icon: AppIcons.delete,
                                    tooltip: 'Убрать из плейлиста',
                                    color: tokens.textTertiary,
                                    onPressed: () => ref
                                        .read(libraryProvider)
                                        .removeFromPlaylist(
                                            widget.playlistId, t),
                                  ),
                                ],
                              ),
                            ),
                            const SkinRowSeparator(),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
