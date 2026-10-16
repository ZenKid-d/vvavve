import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../design/icons/app_icons.dart';
import '../../domain/models/track.dart';
import 'skin_tokens.dart';

/// Поле фильтра в двух темах.
///
/// iOS: скруглённая «лупа» — заливка вложенной поверхностью, иконка поиска
/// внутри поля, крестик очистки справа. iPod: прямой прямоугольник в рамке на
/// фоне корпуса, потому что у настоящего iPod поля ввода не было вовсе и
/// любой «плашкой» он выбивался бы сильнее, чем помогает. Поведение (что
/// фильтрует и когда очищается) одинаковое — различается только форма.
class SkinFilterField extends StatelessWidget {
  const SkinFilterField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.onClear,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  /// null — крестик не показывается (нечего очищать).
  final VoidCallback? onClear;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Больше единицы — поле для длинного ввода (список треков построчно).
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final ipod = id.isIpod;
    final radius = ipod ? tokens.radiusSm : tokens.radiusMd;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      maxLines: maxLines,
      cursorColor: tokens.accent,
      style: tokens.body.copyWith(color: tokens.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: !ipod,
        fillColor: tokens.surfaceAlt,
        hintText: hint,
        hintStyle: tokens.body.copyWith(color: tokens.textTertiary),
        prefixIcon: AppIcon(
          AppIcons.search,
          size: ipod ? 18 : 20,
          color: tokens.textSecondary,
        ),
        suffixIcon: onClear == null
            ? null
            : GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.all(tokens.space12),
                  child: AppIcon(
                    AppIcons.close,
                    size: 16,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.space12,
          vertical: tokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide:
              ipod ? BorderSide(color: tokens.separator) : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide:
              ipod ? BorderSide(color: tokens.separator) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: tokens.accent),
        ),
      ),
    );
  }
}

/// Кнопка-действие в двух темах (сохранить очередь, скачать, создать).
///
/// iOS: «капсуля» — заливка акцентом или контурная с круглыми углами. iPod:
/// прямой прямоугольник, а заливка — инвертированный блок с тёмной подписью.
/// Обе формы умеют иконку [AppIcons.*], чтобы экран не тащил Material-иконки.
class SkinActionButton extends StatelessWidget {
  const SkinActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;

  /// Залитая кнопка (главное действие) против контурной.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final skin = skinOf(context);
    final tokens = skin.tokens;
    final id = skin.id;
    final enabled = onPressed != null;
    final fg = enabled
        ? (filled ? tokens.accentOn : tokens.accent)
        : tokens.textTertiary;
    final bg = filled ? tokens.accent : const Color(0x00000000);
    final radius = id.isIpod ? tokens.radiusSm : tokens.radiusPill;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: filled
                ? null
                : Border.all(
                    color: enabled ? tokens.separator : tokens.surfaceAlt,
                  ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space16,
            vertical: tokens.space8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: 18, color: fg),
                SizedBox(width: tokens.space8),
              ],
              Text(
                label,
                style: (id.isIpod ? tokens.micro : tokens.caption).copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Линейный прогресс-бар из токенов.
///
/// Свой, а не [LinearProgressIndicator], потому что индикатор Material рисует
/// скруглённый хвост и анимацию, которые в монохромном iPod выглядят как
/// инородный элемент, а в iOS-скине не совпадают с радиусами токенов.
class SkinProgressBar extends StatelessWidget {
  const SkinProgressBar({super.key, required this.value, this.height = 4});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: Stack(
        children: [
          Container(height: height, color: tokens.separator),
          FractionallySizedBox(
            widthFactor: v,
            child: Container(height: height, color: tokens.accent),
          ),
        ],
      ),
    );
  }
}

/// Кольцевой прогресс одного трека (загрузка) с процентом внутри.
///
/// Кольцо, а не полоска, потому что треки качаются пачками и у каждого своя
/// скорость: в списке важно видеть «кто ещё идёт и как далеко» одним взглядом,
/// не разыскивая строку с полоской.
class SkinRingProgress extends StatelessWidget {
  const SkinRingProgress({
    super.key,
    required this.value,
    this.size = 28,
    this.indeterminate = false,
  });

  final double value;
  final double size;

  /// Процент неизвестен — рисуем кольцо целиком (фаза еще не началась).
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    final v = value.clamp(0.0, 1.0);
    final showLabel = !indeterminate && v > 0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              value: v,
              track: tokens.separator,
              progress: tokens.accent,
              stroke: size / 10,
            ),
          ),
          if (showLabel)
            Text(
              '${(v * 100).round()}',
              style: tokens.micro.copyWith(color: tokens.accent),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.progress,
    required this.stroke,
  });

  final double value;
  final Color track;
  final Color progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke / 2;
    final arc =
        Rect.fromLTWH(inset, inset, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    // Старт сверху — так кольцо совпадает с «часами» и с остальными
    // индикаторами приложения.
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.progress != progress ||
      old.stroke != stroke;
}

/// Кнопка-иконка приложения: [AppIcon] в квадрате тапа.
///
/// Отдельный примитив, потому что Material-[IconButton] подставляет свой
/// размер и свои отступы, а экран, который рисует «три кнопки в ряд», должен
/// видеть одинаковые 40×40 у всех трёх — иначе ряд «играет».
class SkinIconButton extends StatelessWidget {
  const SkinIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 20,
  });

  final AppIconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  /// Кегль глифа.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = skinOf(context).tokens;
    final c = color ?? tokens.accent;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: AppIcon(icon, size: size, color: c),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

/// Состояние скачивания трека для строки списка, нарисованное в скине.
///
/// Заменяет `core/widgets/track_download_status.dart` не из-за функций (они
/// те же), а из-за цвета: тот виджет берёт акцент из темы Material, и в
/// монохромном iPod кольцо прогресса оставалось бы синим.
class SkinDownloadStatus extends ConsumerWidget {
  const SkinDownloadStatus(this.track, {super.key});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = skinOf(context).tokens;
    final dl = ref.watch(downloadsProvider);

    if (dl.isDownloading(track.uid)) {
      final p = dl.progressFor(track.uid);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.space8),
        child: SkinRingProgress(value: p, size: 22, indeterminate: p == 0),
      );
    }
    if (dl.isDownloaded(track.uid)) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.space8),
        child: AppIcon(AppIcons.downloadDone, size: 20, color: tokens.accent),
      );
    }
    return SkinIconButton(
      icon: AppIcons.download,
      tooltip: 'Скачать трек',
      color: tokens.textTertiary,
      onPressed: () => ref.read(downloadsProvider).download(track),
    );
  }
}
