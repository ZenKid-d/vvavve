import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/recs/recs_providers.dart'
    show waveModeProvider, waveMoodProvider;
import '../../data/recs/wave_mode.dart';
import '../../data/recs/wave_mood.dart';
import '../../design/skin.dart';
import 'home_controller.dart';

/// Чипы главной в двух видах.
///
/// Все три набора (жанры, характер, настроение) — это один и тот же элемент с
/// разными данными, поэтому чип рисуется один раз, а вид ему задаёт скин: в
/// iOS это круглые «таблетки» без рамки, в iPod — прямоугольники в рамке,
/// потому что корпус iPod был прямоугольным и круг там выглядел бы вклеенным.

/// Высота полосы чипов. Держим её собственной константой, а не через
/// токены: это высота строки воркспейса, а не элемент палитры.
const double chipStripHeight = 34;

/// Подпись под настроением, когда ключа Last.fm нет.
///
/// Без ключа у треков нет тегов вообще, поэтому выбор настроения физически
/// ничего не меняет. Честнее показать неактивные чипы с пояснением, чем
/// оставить переключатель, который выглядит рабочим и молчит.
const String moodNeedsLastfmHint = 'Работает с ключом Last.fm в настройках';

/// Жанры: тап запускает радио по жанру.
class GenreChips extends ConsumerWidget {
  const GenreChips({super.key, required this.onGenre});

  final void Function(String genre) onGenre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ChipStrip(
      children: [
        for (final g in homeGenres) HomeChip(label: g, onTap: () => onGenre(g)),
      ],
    );
  }
}

/// Характер волны (Баланс / Любимое / Незнакомое / Популярное).
///
/// Чипы выбора, а не действия: одновременно активен ровно один, и подпись у них
/// пояснительная — «Незнакомое» без пояснения ничем не отличается от опечатки.
class WaveModeChips extends ConsumerWidget {
  const WaveModeChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = SkinScope.of(context);
    final mode = ref.watch(waveModeProvider);
    return _ChipStrip(
      leading: skin.id == SkinId.ipod ? null : 'Характер',
      children: [
        for (final m in WaveMode.values)
          HomeChip(
            label: m.label,
            selected: m == mode,
            onTap: () => setWaveMode(ref, m),
          ),
      ],
    );
  }
}

/// Настроение волны (приблизительно, через теги Last.fm).
class WaveMoodChips extends ConsumerWidget {
  const WaveMoodChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = SkinScope.of(context);
    final tokens = skin.tokens;
    final mood = ref.watch(waveMoodProvider);
    // Ключ читается провайдером, а не из настроек: настроек может быть много,
    // а нужен ровно один факт — есть ли доступ к тегам.
    final enabled = hasLastfmKey(ref);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChipStrip(
            leading: skin.id == SkinId.ipod ? null : 'Настроение',
            children: [
              for (final m in WaveMood.values)
                HomeChip(
                  label: m.label,
                  selected: m == mood,
                  // Активное настроение подсвечиваем даже без ключа: иначе
                  // выбранное значение молча пропало бы из интерфейса.
                  enabled: enabled,
                  onTap: enabled ? () => setWaveMood(ref, m) : null,
                ),
            ],
          ),
          if (!enabled)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.space16,
                tokens.space4,
                tokens.space16,
                0,
              ),
              child: Text(
                moodNeedsLastfmHint,
                style: tokens.micro.copyWith(color: tokens.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Горизонтальная лента чипов. Прокрутка раздельная по осям: список должен
/// листаться, а лента — нет, иначе жест по вертикали уводил бы полосу вместо
/// страницы.
class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.children, this.leading});

  final List<Widget> children;

  /// Подпись-подсказка слева от чипов. В iPod не показываем: там меню держит
  /// монохром и не любит лишние слова наравне с пунктами.
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final skin = SkinScope.of(context);
    final tokens = skin.tokens;
    final leading = this.leading;
    // Подсказка едет вместе с чипами, а не стоит колонкой слева: её длина
    // зависит от скина (типографика разная), и любая фиксированная ширина
    // либо съедала бы место на iPod, либо обрезала подпись на iOS.
    final items = <Widget>[
      if (leading != null)
        Padding(
          padding: EdgeInsets.only(right: tokens.space4),
          child: Center(
            child: Text(
              leading,
              maxLines: 1,
              style: tokens.micro.copyWith(color: tokens.textTertiary),
            ),
          ),
        ),
      ...children,
    ];
    return Padding(
      padding: EdgeInsets.only(top: tokens.space8),
      child: SizedBox(
        height: chipStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: tokens.space16),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: tokens.space8),
          itemBuilder: (_, i) => items[i],
        ),
      ),
    );
  }
}

/// Чип-капсуля.
///
/// [selected] — состояние выбора (инверсия фона), [enabled] — «можно ли
/// нажать». Разделены намеренно: неактивный, но выбранный чип должен остаться
/// видимым, просто приглушённым.
class HomeChip extends StatelessWidget {
  const HomeChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skin = SkinScope.of(context);
    final tokens = skin.tokens;
    // У iPod радиусы почти нулевые, но чип обязан остаться прямоугольником
    // в рамке, а не серым прямоугольником в сером прямоугольнике.
    final boxed = skin.id == SkinId.ipod;
    final fg = switch ((selected, enabled)) {
      (true, _) => tokens.accentOn,
      (_, false) => tokens.textTertiary,
      _ => tokens.textPrimary,
    };
    final disabled = !enabled && !selected;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Material(
        color: selected
            ? tokens.accent
            : (disabled ? tokens.background : tokens.surfaceAlt),
        // Форма задаётся один раз, у Material: иначе рамка iPod и скругление
        // фона жили бы в разных местах и разъезжались на пиксель.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            boxed ? tokens.radiusSm : tokens.radiusPill,
          ),
          side: boxed
              ? BorderSide(color: tokens.separator, width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: boxed ? tokens.space8 : tokens.space12,
            ),
            // На iPod кегль микро с трекингом — родной для меню корпуса, на
            // iOS чип должен читаться как подпись, а не как служебный текст.
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (boxed ? tokens.micro : tokens.caption).copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
