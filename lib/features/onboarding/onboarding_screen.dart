import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics.dart';
import '../../core/providers.dart';
import '../../core/widgets/artwork.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import '../../domain/models/track.dart';
import '../home/home_screen.dart' show recommendationsProvider, dailyPlaylistsProvider;

/// Онбординг (cold start): тема → жанры → артисты → сид профиля.
///
/// Показывается при первом запуске с пустой библиотекой; лайки выбранных
/// артистов сидируют профиль вкуса. Выбор темы — первый шаг, потому что
/// дальше весь онбординг рисуется уже в выбранном оформлении: пользователь
/// сразу видит, что выбрал, а не абстрактные карточки. Можно пропустить.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _genres = [
    'Поп', 'Рок', 'Хип-хоп', 'Рэп', 'Электроника', 'Инди', 'Джаз',
    'Классика', 'Метал', 'R&B', 'Панк', 'Фолк', 'Хаус', 'Лоу-фай',
    'Танцевальная', 'Регги',
  ];

  int _step = 0;
  SkinId? _chosenSkin;
  final Set<String> _selectedGenres = {};
  List<Track> _suggested = const [];
  final Set<String> _selectedUids = {};
  bool _loading = false;
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    final agg = ref.read(aggregatorProvider);
    final byArtist = <String, Track>{};
    for (final g in _selectedGenres) {
      try {
        final res = await agg.search(g, perSource: 12);
        for (final t in res) {
          byArtist.putIfAbsent(t.artist.toLowerCase(), () => t);
        }
      } catch (e) {
        // Жанр не нашёлся в каком-то источнике — не повод валить онбординг,
        // но запись в диагностику помогает понять, почему список артистов пуст.
        Diagnostics.instance.warn('onboarding', 'Поиск жанра «$g» упал: $e');
      }
      if (byArtist.length >= 48) break;
    }
    if (!mounted) return;
    setState(() {
      _suggested = byArtist.values.toList();
      _loading = false;
      _step = 2;
    });
  }

  Future<void> _searchArtists() async {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    List<Track> res;
    try {
      res = await ref.read(aggregatorProvider).search(q, perSource: 10);
    } catch (e) {
      Diagnostics.instance
          .warn('onboarding', 'Поиск артистов «$q» упал: $e');
      res = const [];
    }
    if (!mounted) return;
    final existing = _suggested.map((t) => t.artist.toLowerCase()).toSet();
    final add = [
      for (final t in res)
        if (existing.add(t.artist.toLowerCase())) t
    ];
    setState(() {
      _suggested = [...add, ..._suggested];
      _loading = false;
      _searchCtl.clear();
    });
  }

  Future<void> _finish() async {
    final lib = ref.read(libraryProvider);
    final chosen =
        _suggested.where((t) => _selectedUids.contains(t.uid)).toList();
    for (final t in chosen) {
      await lib.toggleLike(t); // сид: лайк → событие recs → профиль вкуса
    }
    ref.read(prefsProvider).setBool('onboarded', true);
    // Пересобрать ряды/дневные с учётом новых сидов.
    ref.invalidate(recommendationsProvider);
    ref.invalidate(dailyPlaylistsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _skip() {
    ref.read(prefsProvider).setBool('onboarded', true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: Text(switch (_step) {
          0 => 'Выбери оформление',
          1 => 'Выбери жанры',
          _ => 'Выбери артистов',
        }),
        actions: [
          TextButton(onPressed: _skip, child: const Text('Пропустить')),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: t.accent),
            )
          : switch (_step) {
              0 => _themeStep(),
              1 => _genresStep(),
              _ => _artistsStep(),
            },
    );
  }

  /// Шаг выбора темы: обе карточки — настоящие токены каждого скина.
  ///
  /// Тема применяется сразу при тапе (SkinScope над MaterialApp
  /// перерисовывает весь экран), поэтому «превью» здесь не картинка, а
  /// живой интерфейс вокруг.
  Widget _themeStep() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Каким будет плеер? Оформление можно сменить в настройках.',
              style: TextStyle(
                color: SkinScope.of(context).tokens.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final id in SkinId.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SkinCard(
                      id: id,
                      tokens: skinFor(id).tokens,
                      selected: _chosenSkin == id,
                      onTap: () {
                        ref.read(skinProvider.notifier).select(id);
                        setState(() => _chosenSkin = id);
                      },
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _chosenSkin == null ? null : () => setState(() => _step = 1),
                  child: const Text('Далее'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genresStep() {
    final t = SkinScope.of(context).tokens;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'Что ты обычно слушаешь? Выбери пару жанров — с них соберём волну.',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in _genres)
                  FilterChip(
                    label: Text(g),
                    selected: _selectedGenres.contains(g),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _selectedGenres.add(g);
                      } else {
                        _selectedGenres.remove(g);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedGenres.isEmpty ? null : _loadSuggestions,
                child: const Text('Далее'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _artistsStep() {
    final t = SkinScope.of(context).tokens;
    final enough = _selectedUids.length >= 3;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchArtists(),
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              hintText: 'Найти артиста…',
              hintStyle: TextStyle(color: t.textTertiary),
              prefixIcon: const AppIcon(AppIcons.search, size: 20),
              suffixIcon: IconButton(
                icon: const AppIcon(AppIcons.chevronRight, size: 20),
                onPressed: _searchArtists,
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _suggested.isEmpty
              ? Center(
                  child: Text('Ничего не нашлось. Попробуй поиск выше.',
                      style: TextStyle(color: t.textSecondary)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _suggested.length,
                  itemBuilder: (_, i) {
                    final track = _suggested[i];
                    return _ArtistPick(
                      track: track,
                      selected: _selectedUids.contains(track.uid),
                      onTap: () => setState(() {
                        if (!_selectedUids.remove(track.uid)) {
                          _selectedUids.add(track.uid);
                        }
                      }),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enough ? _finish : null,
                child: Text(enough
                    ? 'Готово (${_selectedUids.length})'
                    : 'Выбери минимум 3'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Карточка выбора темы: подложка — фон скина, внутри — его акцент, иконка
/// и подпись. Настоящие токены, а не нарисованный макет: что видит здесь,
/// то и получит после выбора.
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.id,
    required this.tokens,
    required this.selected,
    required this.onTap,
  });

  final SkinId id;
  final DesignTokens tokens;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: BorderRadius.circular(t.radiusLg),
          border: Border.all(
            color: selected ? t.accent : t.separator,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Center(
                child: AppIcon(
                  id == SkinId.ios ? AppIcons.home : AppIcons.library,
                  size: 22,
                  color: tokens.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id == SkinId.ios
                        ? 'Классический iOS'
                        : 'iPod Classic',
                    style: TextStyle(
                      fontSize: t.headline.fontSize,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    id == SkinId.ios
                        ? 'Плотные списки, нижняя панель, Cover Flow'
                        : 'Графит, меню, бегущая строка, колесо',
                    style: TextStyle(
                      fontSize: t.caption.fontSize,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) AppIcon(AppIcons.check, size: 20, color: t.accent),
          ],
        ),
      ),
    );
  }
}

class _ArtistPick extends StatelessWidget {
  const _ArtistPick({
    required this.track,
    required this.selected,
    required this.onTap,
  });
  final Track track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SkinScope.of(context).tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Artwork(track.artworkUrl,
                  size: 64, seed: track.uid, radius: t.radiusMd),
              if (selected)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: AppIcon(AppIcons.check, color: t.accentOn, size: 26),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textPrimary)),
        ],
      ),
    );
  }
}