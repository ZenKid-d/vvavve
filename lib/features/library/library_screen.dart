import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/album_menu.dart';
import '../../core/io/file_io.dart';
import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_card.dart';
import '../../core/widgets/track_download_status.dart';
import '../../domain/models/album_result.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import '../album/album_screen.dart';
import '../common/track_list_screen.dart';
import 'library_controller.dart';

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
    _search.clear();
    ref.read(libraryQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final libQuery = ref.watch(libraryQueryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < libraryTabs.length; i++) ...[
                          _Toggle(
                              label: libraryTabs[i],
                              active: _tab == LibraryTab.values[i],
                              onTap: () => _selectTab(LibraryTab.values[i])),
                          const SizedBox(width: 8),
                        ],
                    ],
                  ),
                ),
              ),
              if (_tab == LibraryTab.playlists) ...[
                _PlaylistSortButton(),
                IconButton(
                    icon: const Icon(Icons.library_add_outlined),
                    tooltip: 'Импорт плейлиста',
                    onPressed: _import),
                IconButton(
                    icon: const Icon(Icons.add), onPressed: _createPlaylist),
              ],
              if (_tab == LibraryTab.liked)
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Скачать все лайки',
                  onPressed: () async =>
                      _snack(await LibraryActions(ref).downloadLiked()),
                ),
            ],
          ),
        ),
        if (_tab != LibraryTab.queue)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: (v) =>
                  ref.read(libraryQueryProvider.notifier).state =
                      v.trim().toLowerCase(),
              decoration: InputDecoration(
                isDense: true,
                hintText: _tab == LibraryTab.playlists
                    ? 'Фильтр плейлистов'
                    : 'Фильтр по названию или артисту',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: libQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          ref.read(libraryQueryProvider.notifier).state = '';
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        Expanded(child: _bodyFor(_tab)),
      ],
    );
  }

  Widget _bodyFor(LibraryTab t) => switch (t) {
        LibraryTab.playlists => _PlaylistsView(),
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

  /// null — показывать нечего (операция отменена или прошла штатно).
  void _snack(String? msg) {
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showLoading() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

  /// Импорт. Диалоги ввода и списки выбора остаются здесь (это чистый UI),
  /// а сама операция — в [LibraryActions]: по нажатию кнопки «Импорт» screen
  /// только спрашивает, откуда, и показывает то, что вернул контроллер.
  Future<void> _import() async {
    final src = await showModalBottomSheet<PlaylistImportSource>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Импорт плейлиста',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            ListTile(
                leading: const FaIcon(FontAwesomeIcons.youtube,
                    color: Color(0xFFFF0000), size: 20),
                title: const Text('Из YouTube (ссылка)'),
                onTap: () =>
                    Navigator.pop(context, PlaylistImportSource.youtube)),
            ListTile(
                leading: const FaIcon(FontAwesomeIcons.youtube,
                    color: Color(0xFFFF0000), size: 20),
                title: const Text('Лайки YouTube Music (вход Google)'),
                onTap: () =>
                    Navigator.pop(context, PlaylistImportSource.youtubeLikes)),
            ListTile(
                leading: const FaIcon(FontAwesomeIcons.yandex,
                    color: Color(0xFFFFCC00), size: 20),
                title: const Text('Из Яндекса (мои плейлисты)'),
                onTap: () => Navigator.pop(context, PlaylistImportSource.yandex)),
            ListTile(
                leading: const FaIcon(FontAwesomeIcons.spotify,
                    color: Color(0xFF1DB954), size: 20),
                title: const Text('Из Spotify (ссылка)'),
                subtitle: Text('Плейлист/альбом → играем из свободных источников',
                    style: TextStyle(color: AppColors.white45, fontSize: 11)),
                onTap: () =>
                    Navigator.pop(context, PlaylistImportSource.spotify)),
            ListTile(
                leading: const Icon(Icons.format_list_bulleted),
                title: const Text('Из списка (текст)'),
                subtitle: Text('«Артист — Трек» построчно',
                    style: TextStyle(color: AppColors.white45, fontSize: 11)),
                onTap: () => Navigator.pop(context, PlaylistImportSource.list)),
            ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Из файла (.json)'),
                onTap: () => Navigator.pop(context, PlaylistImportSource.file)),
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

  /// Прячет индикатор загрузки. Отдельный метод, потому что во всех ветках
  /// импорта («поймали ошибку», «ничего не нашли», «сохранили») крутилка должна
  /// закрыться одинаково — забытый pop оставлял бы её навсегда.
  void _hideLoading() {
    if (mounted) Navigator.pop(context); // индикатор
  }

  Future<void> _importSpotify() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Импорт из Spotify'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://open.spotify.com/playlist/…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Импорт')),
        ],
      ),
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
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Импорт по списку'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Eminem — Lose Yourself\nThe Weeknd — Blinding Lights\n…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Найти')),
        ],
      ),
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
    final name = await _askName(context, 'Название плейлиста',
        initial: 'Мой список');
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
    final choice = await showDialog<YoutubeLikesTarget>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Куда добавить лайки?'),
        content: Text('Найдено треков: ${tracks.length}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, YoutubeLikesTarget.playlist),
              child: const Text('Отдельным плейлистом')),
          TextButton(
              onPressed: () => Navigator.pop(context, YoutubeLikesTarget.liked),
              child: const Text('В «Избранное»')),
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
    final picked = await showModalBottomSheet<YandexPlaylist>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Выберите плейлист',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            for (final p in pls)
              ListTile(
                  title: Text(p.title),
                  subtitle: Text('${p.count} треков'),
                  onTap: () => Navigator.pop(context, p)),
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

class _LikedView extends ConsumerWidget {
  const _LikedView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(libraryQueryProvider);
    final lib = ref.watch(libraryProvider);
    final liked = lib.liked.where((t) => matchTrack(t, q)).toList();
    final likedAlbums =
        lib.likedAlbums.where((a) => matchAlbum(a, q)).toList();
    if (liked.isEmpty && likedAlbums.isEmpty) {
      return Center(
        child: Text(q.isEmpty ? 'Нет лайкнутых треков' : 'Ничего не найдено',
            style: TextStyle(color: AppColors.white45)),
      );
    }
    return ListView.builder(
      itemCount: liked.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _LikedAlbumsRow(likedAlbums);
        final t = liked[i - 1];
        return TrackRow(
          track: t,
          onTap: () => playTrack(ref, context, t, queue: liked),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrackDownloadStatus(t),
              IconButton(
                icon: const Icon(Icons.favorite, color: AppColors.danger),
                onPressed: () => ref.read(libraryProvider).toggleLike(t),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LikedAlbumsRow extends ConsumerWidget {
  const _LikedAlbumsRow(this.albums);
  final List<AlbumResult> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text('Альбомы',
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.white60,
                  fontWeight: FontWeight.w500)),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = albums[i];
              return SizedBox(
                width: 120,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AlbumScreen(seed: a.toSeedTrack()))),
                  onLongPress: () => showAlbumMenu(context, ref, a),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Artwork(a.artworkUrl, size: 120, seed: a.uid),
                      const SizedBox(height: 6),
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w500)),
                      Text(a.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.white45)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 14),
      ],
    );
  }
}

class _DownloadsView extends ConsumerWidget {
  const _DownloadsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.watch(downloadsProvider);
    final q = ref.watch(libraryQueryProvider);
    // Недавно скачанные — сверху.
    final dl = ctl.downloads.reversed
        .where((t) => matchTrack(t, q))
        .toList();
    final busy =
        ctl.inProgress.where((t) => matchTrack(t, q)).toList();
    final accent = Theme.of(context).colorScheme.primary;

    if (dl.isEmpty && busy.isEmpty && !ctl.playlistBusy) {
      return Center(
        child: Text(q.isEmpty ? 'Нет скачанных треков' : 'Ничего не найдено',
            style: TextStyle(color: AppColors.white45)),
      );
    }
    // Список скачанных строим лениво (SliverList) — при большой библиотеке
    // не создаём сотни строк с картинками разом.
    return CustomScrollView(
      slivers: [
        if (ctl.playlistBusy)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Скачивается плейлист: ${ctl.playlistName} · '
                      '${(ctl.playlistProgress * 100).round()}%',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.white60)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: ctl.playlistProgress, color: accent),
                  ),
                ],
              ),
            ),
          ),
        if (busy.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final t = busy[i];
                return ListTile(
                  leading: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        value: ctl.progressFor(t.uid) == 0
                            ? null
                            : ctl.progressFor(t.uid),
                        strokeWidth: 2,
                        color: accent),
                  ),
                  title: Text(t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${t.artist} · ${(ctl.progressFor(t.uid) * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.white45, fontSize: 12)),
                );
              },
              childCount: busy.length,
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final t = dl[i];
              return TrackRow(
                track: t,
                onTap: () => playTrack(ref, context, t, queue: dl),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.white60),
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

Future<String?> _askName(BuildContext context, String title,
    {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface2,
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Название'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Сохранить')),
      ],
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? Colors.white24 : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              color: active ? Colors.white : AppColors.white45,
            )),
      ),
    );
  }
}

/// Иконки умных подборок — всё, что от них осталось в UI. Сами списки
/// считает [buildSmartPlaylists], чтобы логика не жила в вёрстке.
IconData _smartIcon(SmartPlaylistKind kind) => switch (kind) {
      SmartPlaylistKind.top => Icons.local_fire_department,
      SmartPlaylistKind.recent => Icons.history,
      SmartPlaylistKind.liked => Icons.favorite,
    };

class _PlaylistSortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<PlaylistSort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Сортировка',
      onSelected: (v) => ref.read(playlistSortProvider.notifier).state = v,
      itemBuilder: (_) => [
        for (final e in playlistSortLabels.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                Icon(
                    ref.read(playlistSortProvider) == e.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18),
                const SizedBox(width: 10),
                Text(e.value),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlaylistsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final q = ref.watch(libraryQueryProvider);
    final sort = ref.watch(playlistSortProvider);
    final playlists = sortPlaylists(
      lib.playlists
          .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
          .toList(),
      sort,
    );
    final smart = buildSmartPlaylists(lib, q);
    final accent = Theme.of(context).colorScheme.primary;

    return ListView(
      children: [
        for (final s in smart)
          if (s.tracks.isNotEmpty)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(_smartIcon(s.kind), color: accent, size: 20),
              ),
              title: Text(s.title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${s.tracks.length} треков · авто',
                  style: TextStyle(color: AppColors.white45, fontSize: 12)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TrackListScreen(title: s.title, tracks: s.tracks),
              )),
            ),
        const Divider(height: 8),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
                q.isEmpty
                    ? 'Своих плейлистов пока нет. Нажмите + или импортируйте.'
                    : 'Плейлисты не найдены.',
                style: TextStyle(color: AppColors.white45)),
          ),
        for (final pl in playlists)
          ListTile(
            leading: SizedBox(
              width: 52,
              height: 52,
              child: Artwork(pl.cover?.artworkUrl, seed: pl.id, radius: 12),
            ),
            title: Text(pl.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('${pl.tracks.length} треков',
                style: TextStyle(color: AppColors.white45, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _playlistMenu(context, ref, pl),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlistId: pl.id),
            )),
          ),
      ],
    );
  }

  void _playlistMenu(BuildContext context, WidgetRef ref, PlaylistX pl) {
    final actions = LibraryActions(ref);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Переименовать'),
              onTap: () async {
                Navigator.pop(context);
                final name = await _askName(context, 'Переименовать',
                    initial: pl.name);
                if (name != null && name.isNotEmpty) {
                  await ref.read(libraryProvider).renamePlaylist(pl.id, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Убрать дубликаты'),
              onTap: () async {
                Navigator.pop(context);
                final msg = await actions.removeDuplicates(pl.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Экспорт в файл'),
              onTap: () {
                Navigator.pop(context);
                actions.exportPlaylist(pl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () {
                ref.read(libraryProvider).deletePlaylist(pl.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
    final pl = ref.watch(libraryProvider).playlists.firstWhere(
        (e) => e.id == widget.playlistId,
        orElse: () => PlaylistX(id: widget.playlistId, name: 'Плейлист'));
    final downloads = ref.watch(downloadsProvider);
    final tracks =
        pl.tracks.where((t) => matchTrack(t, _q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(pl.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Скачать плейлист',
            onPressed: (pl.tracks.isEmpty || downloads.playlistBusy)
                ? null
                : () => ref
                    .read(downloadsProvider)
                    .downloadPlaylist(pl.name, pl.tracks),
          ),
        ],
        bottom: downloads.playlistBusy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                    value: downloads.playlistProgress),
              )
            : null,
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: pl.tracks.isEmpty
          ? Center(
              child: Text('Плейлист пуст',
                  style: TextStyle(color: AppColors.white45)))
          : Column(
              children: [
                if (pl.tracks.length >= 8)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) =>
                          setState(() => _q = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Поиск в плейлисте',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _q.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _q = '');
                                },
                              ),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: tracks.isEmpty
                      ? Center(
                          child: Text('Ничего не найдено',
                              style: TextStyle(color: AppColors.white45)))
                      : ListView.builder(
                          itemCount: tracks.length,
                          itemBuilder: (_, i) {
                            final t = tracks[i];
                            return TrackRow(
                              track: t,
                              onTap: () =>
                                  playTrack(ref, context, t, queue: tracks),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TrackDownloadStatus(t),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    tooltip: 'Убрать из плейлиста',
                                    onPressed: () => ref
                                        .read(libraryProvider)
                                        .removeFromPlaylist(
                                            widget.playlistId, t),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _QueueView extends ConsumerWidget {
  const _QueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pc = ref.watch(playbackProvider);
    final queue = pc.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text('Очередь пуста',
            style: TextStyle(color: AppColors.white45)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Сохранить очередь как плейлист'),
              onPressed: () async {
                final name = await _askName(context, 'Новый плейлист',
                    initial: 'Очередь');
                if (name != null && name.isNotEmpty) {
                  final msg =
                      await LibraryActions(ref).saveQueueAsPlaylist(name, queue);
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
            itemBuilder: (_, i) {
              final t = queue[i];
              return TrackRow(
                key: ValueKey(t.uid),
                track: t,
                active: t.uid == pc.current?.uid,
                onTap: () => playTrack(ref, context, t, queue: queue,
                    openPlayer: false),
                trailing: const Icon(Icons.drag_handle),
              );
            },
          ),
        ),
      ],
    );
  }
}
