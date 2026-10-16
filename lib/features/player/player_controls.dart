import 'package:flutter/material.dart';

import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';

/// Контракт между экраном плеера и двумя его видами.
///
/// Экран плеера — единственный, кто знает про провайдеры: он собирает
/// состояние и колбэки в один объект и отдаёт его вёрстке. Виды плеера
/// (iOS / iPod) не знают ни про Riverpod, ни про плеер вообще — поэтому их
/// можно показать в превью и в обычном виджет-тесте, подставив любые треки.
///
/// Объект собирается [PlayerUi] целиком в одном месте, а не по полям в
/// конструкторах виджетов: полей много, и поштучная передача в двух вёрстках
/// рассинхронизировалась бы уже на втором экране.
class PlayerUi {
  const PlayerUi({
    required this.tokens,
    required this.track,
    required this.queue,
    required this.index,
    required this.direction,
    required this.isPlaying,
    required this.isLoading,
    required this.shuffleOn,
    required this.repeatActive,
    required this.repeatOne,
    required this.duration,
    required this.error,
    required this.liked,
    required this.disliked,
    required this.downloaded,
    required this.downloading,
    required this.downloadProgress,
    required this.service,
    required this.originService,
    required this.onClose,
    required this.onMore,
    required this.onLyrics,
    required this.onQueue,
    required this.onDownload,
    required this.onAddToPlaylist,
    required this.onLike,
    required this.onDislike,
    required this.onArtist,
    required this.onAlbum,
    required this.onSelectIndex,
    required this.onRetry,
    required this.onTogglePlay,
    required this.onPrev,
    required this.onNext,
    required this.onShuffle,
    required this.onCycleRepeat,
    required this.onSeek,
  });

  /// Токены активного скина: вся вёрстка берёт числа только отсюда.
  final DesignTokens tokens;

  final Track track;

  /// Очередь целиком — по ней листает Cover Flow.
  final List<Track> queue;

  /// Индекс [track] в [queue]; -1 — трека в очереди нет (подстановка/радио).
  final int index;

  /// Направление последней смены трека: 1 — вперёд, -1 — назад. Нужен анимации
  /// подъёма обложки, чтобы она шла в ту же сторону, что и переход.
  final int direction;

  final bool isPlaying;
  final bool isLoading;
  final bool shuffleOn;
  final bool repeatActive;
  final bool repeatOne;
  final Duration duration;
  final String? error;

  final bool liked;
  final bool disliked;
  final bool downloaded;
  final bool downloading;

  /// Прогресс загрузки 0..1 (null — индикатор без значения).
  final double? downloadProgress;

  /// Сервис, из которого реально играет трек, и его родной источник.
  final SourceType service;
  final SourceType? originService;

  final VoidCallback onClose;
  final VoidCallback onMore;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final VoidCallback onDownload;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onArtist;
  final VoidCallback onAlbum;

  /// Выбор трека из Cover Flow (свайп/тап по соседней карточке).
  final ValueChanged<int> onSelectIndex;

  /// Повтор после ошибки воспроизведения.
  final VoidCallback onRetry;

  final VoidCallback onTogglePlay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onCycleRepeat;
  final ValueChanged<Duration> onSeek;
}

/// Ряд управления плеером: shuffle · назад · play/pause · вперёд · repeat.
///
/// Один виджет на обе темы — решение владельца проекта: управление должно
/// выглядеть одинаково, различается только оформление (берётся из токенов), а не
/// сам жест и порядок кнопок. Иначе через месяц в одном плеере появится
/// «iOS-вариант», а в другом «iPod-вариант» и пользовательу придётся
/// переучиваться при переключении темы.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.tokens,
    required this.isPlaying,
    required this.isLoading,
    required this.shuffleOn,
    required this.repeatActive,
    required this.repeatOne,
    required this.onTogglePlay,
    required this.onPrev,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    this.diameter = 66,
  });

  final DesignTokens tokens;
  final bool isPlaying;
  final bool isLoading;
  final bool shuffleOn;
  final bool repeatActive;
  final bool repeatOne;

  final VoidCallback onTogglePlay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  /// Диаметр круглой кнопки. Параметр, а не константа: в iPod-обрамлении ряд
  /// уже, и кнопка должна ужиматься вместе с панелью.
  final double diameter;

  /// Минимальная зона касания боковых кнопок. Иконка 26 px сама по себе —
  /// это меньше, чем палец; кликабельной должна быть вся кнопка.
  static const double _tapTarget = 48;

  @override
  Widget build(BuildContext context) {
    // Выключенные переключатели гаснут до tertiary: включённые светятся
    // акцентом, и «что сейчас включено» читается с одного взгляда.
    final muted = tokens.textTertiary;
    final active = tokens.accent;
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _ControlButton(
              tokens: tokens,
              icon: AppIcons.shuffle,
              color: shuffleOn ? active : muted,
              semanticLabel: 'Перемешать',
              onTap: onShuffle,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ControlButton(
              tokens: tokens,
              icon: AppIcons.skipPrev,
              color: tokens.textPrimary,
              semanticLabel: 'Предыдущий трек',
              size: 30,
              onTap: onPrev,
            ),
          ),
        ),
        _PlayButton(
          tokens: tokens,
          isPlaying: isPlaying,
          isLoading: isLoading,
          diameter: diameter,
          onTap: onTogglePlay,
        ),
        Expanded(
          child: Center(
            child: _ControlButton(
              tokens: tokens,
              icon: AppIcons.skipNext,
              color: tokens.textPrimary,
              semanticLabel: 'Следующий трек',
              size: 30,
              onTap: onNext,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ControlButton(
              tokens: tokens,
              icon: repeatOne ? AppIcons.repeatOne : AppIcons.repeat,
              color: repeatActive ? active : muted,
              semanticLabel: 'Повтор',
              onTap: onRepeat,
            ),
          ),
        ),
      ],
    );
  }
}

/// Круглая кнопка play/pause.
///
/// Во время загрузки показываем кольцо прогресса вместо глифа: иначе кнопка
/// выглядит «залипшей» — нажатие есть, а ответа нет.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.tokens,
    required this.isPlaying,
    required this.isLoading,
    required this.diameter,
    required this.onTap,
  });

  final DesignTokens tokens;
  final bool isPlaying;
  final bool isLoading;
  final double diameter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isPlaying ? 'Пауза' : 'Играть',
      child: Material(
        color: tokens.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: diameter,
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: diameter * 0.42,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accentOn,
                      ),
                    )
                  : AppIcon(
                      isPlaying ? AppIcons.pause : AppIcons.play,
                      size: diameter * 0.40,
                      // На крупном кегле штрих 1.8 px волосяной — усиливаем.
                      strokeScale: 1.2,
                      color: tokens.accentOn,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Боковая кнопка ряда: иконка в зоне касания 48 px.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tokens,
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    this.size = 26,
  });

  final DesignTokens tokens;
  final AppIconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: _hitRadius(size),
        child: SizedBox.square(
          dimension: PlayerControls._tapTarget,
          child: Center(
            child: AppIcon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }

  /// Отклик ровно на зону касания: ripple не должен превращаться в круг радиуса
  /// в пол-экрана вокруг мелкой иконки.
  double _hitRadius(double iconSize) =>
      PlayerControls._tapTarget > iconSize * 1.6
          ? PlayerControls._tapTarget
          : iconSize * 1.6;
}

/// Нижний ряд инструментов: текст песни, очередь, загрузка, плейлист,
/// лайк, дизлайк.
///
/// Общий для обеих тем по той же причине, что и [PlayerControls]: набор
/// действий одинаков, отличается только цвет и радиусы.
class PlayerTools extends StatelessWidget {
  const PlayerTools({
    super.key,
    required this.tokens,
    required this.liked,
    required this.disliked,
    required this.downloaded,
    required this.downloading,
    required this.downloadProgress,
    required this.onLyrics,
    required this.onQueue,
    required this.onDownload,
    required this.onAddToPlaylist,
    required this.onLike,
    required this.onDislike,
  });

  final DesignTokens tokens;
  final bool liked;
  final bool disliked;
  final bool downloaded;
  final bool downloading;
  final double? downloadProgress;

  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final VoidCallback onDownload;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final muted = tokens.textSecondary;
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _ToolButton(
              icon: AppIcons.lyrics,
              color: muted,
              semanticLabel: 'Текст песни',
              onTap: onLyrics,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ToolButton(
              icon: AppIcons.queue,
              color: muted,
              semanticLabel: 'Очередь',
              onTap: onQueue,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: downloading
                ? _DownloadProgress(
                    tokens: tokens,
                    progress: downloadProgress,
                    semanticLabel: 'Загрузка',
                    onTap: onDownload,
                  )
                : _ToolButton(
                    icon: downloaded
                        ? AppIcons.downloadDone
                        : AppIcons.download,
                    color: downloaded ? tokens.accent : muted,
                    semanticLabel: downloaded ? 'Удалить загрузку' : 'Скачать',
                    onTap: onDownload,
                  ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ToolButton(
              icon: AppIcons.plus,
              color: muted,
              semanticLabel: 'В плейлист',
              onTap: onAddToPlaylist,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ToolButton(
              icon: liked ? AppIcons.heartFilled : AppIcons.heart,
              color: liked ? tokens.accent : muted,
              semanticLabel: liked ? 'Убрать из любимых' : 'В любимое',
              onTap: onLike,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ToolButton(
              icon: AppIcons.thumbDown,
              color: disliked ? tokens.warning : muted,
              semanticLabel: 'Не нравится',
              onTap: onDislike,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final AppIconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Кегль инструмента: он мельче транспорта — инструменты вторичны.
  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: _size,
        child: Padding(
          padding: const EdgeInsets.all(PlayerControls._tapTarget / 4),
          child: AppIcon(icon, size: _size, color: color),
        ),
      ),
    );
  }
}

/// Индикатор загрузки с процентом внутри — вместо отдельной подписи под
/// кнопкой, чтобы ряд инструментов не «прыгал» на время скачивания.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({
    required this.tokens,
    required this.progress,
    required this.semanticLabel,
    required this.onTap,
  });

  final DesignTokens tokens;

  /// null — файл скачивается, но сервер не отдаёт размер (тогда кольцо
  /// неопределённое).
  final double? progress;

  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = (progress ?? 0).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  value: progress == null || progress == 0 ? null : value,
                  strokeWidth: 2,
                  color: tokens.accent,
                ),
              ),
              if (value > 0)
                Text(
                  '${(value * 100).round()}',
                  style: tokens.micro
                      .copyWith(color: tokens.accent, height: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Время в формате LCD: `m:ss`.
///
/// Общее для обеих шкал прогресса и для подписи таймера сна в меню.
/// Часы сверху 60 минут не показываем — трек длиннее часа встречается, но на
/// узком экране лишние цифры съедают разряд, которого не хватает секундам.
String formatMediaTime(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final m = safe.inMinutes.remainder(60);
  final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Иконка-префикс подписи-ссылки.
enum PlayerLinkIcon { album }

/// Подпись, которая открывает другой экран (исполнитель, альбом).
///
/// Общая для обеих тем: различаются только кегль и цвет, а ведут себя
/// одинаково — иначе в iPod подпись перестала бы быть ссылкой.
class PlayerLink extends StatelessWidget {
  const PlayerLink({
    super.key,
    required this.tokens,
    required this.text,
    required this.style,
    required this.semanticLabel,
    required this.onTap,
    this.leadingIcon,
  });

  final DesignTokens tokens;
  final String text;
  final TextStyle style;
  final String semanticLabel;
  final VoidCallback onTap;
  final PlayerLinkIcon? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                AppIcon(
                  AppIcons.library,
                  size: _leadingSize,
                  color: style.color,
                ),
                SizedBox(width: tokens.space4),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Иконка альбома чуть меньше подписи: она подсказывает, а не читается.
  static const double _leadingSize = 14;
}

/// Ошибка воспроизведения с кнопкой «Повтор».
///
/// Одинаково для обеих тем: состояние ошибки не должно выглядеть по-разному в
/// зависимости от выбранной темы — пользователь в обоих случаях должен видеть
/// одно и то же. Прозрачности подобраны так, чтобы блок читался и на
/// iOS-градите, и на монохромном iPod.
class PlayerErrorBar extends StatelessWidget {
  const PlayerErrorBar({
    super.key,
    required this.tokens,
    required this.message,
    required this.onRetry,
  });

  final DesignTokens tokens;
  final String message;
  final VoidCallback onRetry;

  static const double _dangerAlpha = 0.12;
  static const double _dangerBorderAlpha = 0.3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tokens.space8,
        tokens.space4,
        tokens.space4,
        tokens.space4,
      ),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: _dangerAlpha),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: tokens.danger.withValues(alpha: _dangerBorderAlpha),
        ),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.warning, color: tokens.danger, size: 18),
          SizedBox(width: tokens.space8),
          Expanded(
            child: Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: tokens.caption.copyWith(color: tokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Повтор',
              style: tokens.caption.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}