import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/play_action.dart';
import '../../core/providers.dart';
import '../../core/routing/app_router.dart';
import '../../data/recommendation_service.dart' show RecoRow;
import '../../design/icons/app_icons.dart';
import '../../design/ios/ios_widgets.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';
import 'genre_chips.dart';
import 'home_controller.dart';
import 'track_row_home.dart';
import 'wave_card.dart';

/// Главная iOS-скина: плотная лента, в которой главное — карточка «Моя волна».
///
/// Раскладка идёт от «что послушать сейчас» к «что вообще есть»: приветствие,
/// волна, переключатели её характера, быстрые входы, и только потом подборки и
/// лента источников. Всё, что можно потрогать одним жестом, поднято вверх.
class IosHomeView extends ConsumerWidget {
  const IosHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outer = SkinScope.maybeOf(context);
    final skin = outer ?? skinFor(SkinId.ios);
    final tokens = skin.tokens;

    final lib = ref.watch(libraryProvider);
    final history = lib.history;
    final feed = ref.watch(feedProvider);
    // Фильтрация вынесена в контроллер: чёрный список и дедуп должны вести
    // себя одинаково во всех рядах, а не «примерно одинаково».
    final recos = filterRows(
      ref.watch(recommendationsProvider).value ?? const <RecoRow>[],
      lib.isArtistBlacklisted,
    );
    final daily = filterRows(
      ref.watch(dailyPlaylistsProvider).value ?? const <RecoRow>[],
      lib.isArtistBlacklisted,
    );
    final canRadio = hasSomethingToPlay(history, lib.liked);

    final content = SkinCanvas(
      tokens: tokens,
      child: RefreshIndicator(
        onRefresh: () => refreshHome(ref),
        child: CustomScrollView(
          // AlwaysScrollable — иначе короткий экран (пустая библиотека) не
          // даёт потянуть, и refresh нечего было бы запускать.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Greeting(tokens: tokens)),
            // Волна и её переключатели прячем, когда слушать нечего: кнопка,
            // которая всегда отвечает «мало данных», учит пользователя, что
            // кнопка не работает.
            if (canRadio) ...[
              SliverToBoxAdapter(
                child: WaveCard(onTap: () => startWave(ref, context)),
              ),
              const SliverToBoxAdapter(child: WaveModeChips()),
              const SliverToBoxAdapter(child: WaveMoodChips()),
            ],
            SliverToBoxAdapter(
              child: GenreChips(
                onGenre: (g) => startGenreRadio(ref, context, g),
              ),
            ),
            SliverToBoxAdapter(
              child: _LinkTile(
                tokens: tokens,
                icon: AppIcons.sparkles,
                title: 'Новинки и чарты',
                onTap: () => context.push(Routes.charts),
              ),
            ),
            if (lib.followedArtists.isNotEmpty)
              SliverToBoxAdapter(
                child: _LinkTile(
                  tokens: tokens,
                  icon: AppIcons.heart,
                  title: 'Мои артисты',
                  subtitle: 'Новинки от ${lib.followedArtists.length} артистов',
                  onTap: () => context.push(Routes.followedArtists),
                ),
              ),
            if (history.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  tokens: tokens,
                  title: 'Продолжить слушать',
                ),
              ),
              SliverToBoxAdapter(
                child: HomeCoverRow(
                  tokens: tokens,
                  tracks: history.take(continueListeningLimit).toList(),
                  onTap: (track, queue) =>
                      playTrack(ref, context, track, queue: queue),
                ),
              ),
            ],
            for (final row in daily) ...[
              SliverToBoxAdapter(
                child: SectionHeader(tokens: tokens, title: row.title),
              ),
              SliverToBoxAdapter(
                child: HomeCoverRow(
                  tokens: tokens,
                  tracks: row.tracks,
                  onTap: (track, queue) =>
                      playTrack(ref, context, track, queue: queue),
                ),
              ),
            ],
            for (final row in recos) ...[
              SliverToBoxAdapter(
                child: SectionHeader(tokens: tokens, title: row.title),
              ),
              SliverToBoxAdapter(
                child: HomeCoverRow(
                  tokens: tokens,
                  tracks: row.tracks,
                  onTap: (track, queue) =>
                      playTrack(ref, context, track, queue: queue),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(tokens: tokens, title: 'Со всех сервисов'),
            ),
            feed.when(
              loading: () => SliverToBoxAdapter(
                child: LoadingBlock(tokens: tokens),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorBlock(
                  tokens: tokens,
                  message: 'Не удалось загрузить ленту.\n$e',
                  onRetry: () => ref.invalidate(feedProvider),
                ),
              ),
              data: (all) {
                final tracks = filterTracks(all, lib.isArtistBlacklisted);
                if (tracks.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space16,
                        vertical: tokens.space24,
                      ),
                      child: Text(
                        'Пусто. Включите источники в Настройках.',
                        style:
                            tokens.body.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.space16,
                    0,
                    tokens.space16,
                    tokens.space24,
                  ),
                  sliver: SliverGrid(
                    // Крупнее, чем кажется нужным: в ячейке обложка плюс две
                    // строки подписей, и на узком экране «плотный» коэффициент
                    // даёт обрезку текста, а не экономию пары пикселей.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: tokens.space12,
                      crossAxisSpacing: tokens.space12,
                      childAspectRatio: 0.74,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => HomeTrackTile(
                        tokens: tokens,
                        track: tracks[i],
                        onTap: () => playTrack(
                          ref,
                          context,
                          tracks[i],
                          queue: tracks,
                        ),
                      ),
                      childCount: tracks.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    // Примитивы дизайна (строки, карточка волны, блоки состояния) читают скин
    // из контекста. Экран обязаны монтировать под оболочкой, но превью и
    // тесты часто собирают его сами — поэтому подстраховываемся своей копией
    // скина, а не падающим assert'ом.
    return outer == null ? SkinScope(skin: skin, child: content) : content;
  }
}

/// Приветствие. Заголовок — токен `display`: на плотной тёмной главной это
/// единственный крупный текст, и он должен читаться как имя экрана.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space12,
        tokens.space16,
        tokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingFor(DateTime.now()),
            style: tokens.display.copyWith(color: tokens.textPrimary),
          ),
          SizedBox(height: tokens.space2),
          Text(
            'Всё, что ты слушаешь — в одном месте',
            style: tokens.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Ссылка-раздел: иконка, подпись и шеврон. Ведёт на уже существующий экран,
/// поэтому подпись должна называть раздел, а не действие.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final DesignTokens tokens;
  final AppIconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space8),
      child: IosListRow(
        tokens: tokens,
        leading: icon,
        title: title,
        subtitle: subtitle,
        trailing: AppIcon(
          AppIcons.chevronRight,
          size: 18,
          color: tokens.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }
}
