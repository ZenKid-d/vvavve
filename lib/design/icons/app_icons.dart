import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../skin.dart';

/// Набор отрисовки иконок. Разные скины ведут себя по-разному даже для
/// одного и того же действия, поэтому «иконка» здесь — это не ресурс, а
/// набор штрихов, выбираемый по [IconStyle].
enum IconStyle {
  /// Тонкие линии со скруглёнными концами (iOS).
  ios,

  /// Плотные заливки и жирные штрихи (iPod).
  ipod,
}

extension SkinIdIconStyle on SkinId {
  IconStyle get iconStyle =>
      this == SkinId.ipod ? IconStyle.ipod : IconStyle.ios;
}

/// Иконка в терминах приложения: код экрана не знает ни про Material, ни про
/// то, iPod перед ним или iOS.
abstract class AppIconData {
  /// Запасной Unicode-глиф. Используется, только если для иконки ещё нет
  /// painter'а (см. пометки `TODO(iPod)`), и как семантическое имя в тестах.
  IconData get glyph;

  /// Рекомендованный кегль. Экран может переопределить его (см. [AppIcon.size]).
  double get size;
}

/// Единственная точка входа для иконки: виджет сам достаёт стиль из скина.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.style,
    this.strokeScale = 1,
  });

  final AppIconData icon;
  final double? size;
  final Color? color;

  /// Переопределение стиля. Обычно не нужно — скин в контексте уже знает,
  /// какой набор рисовать; нужен в тестах и в превью.
  final IconStyle? style;

  /// Усиление толщины линии для крупных размеров: на маленьком кегле штрих
  /// 1.8 px почти не виден, а на 64 px становится волосяным.
  final double strokeScale;

  @override
  Widget build(BuildContext context) {
    final s = style ?? SkinScope.maybeOf(context)?.id.iconStyle ?? IconStyle.ios;
    final d = size ?? icon.size;
    final c = color ?? const Color(0xFFFFFFFF);
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: icon,
          style: s,
          color: c,
          strokeScale: strokeScale,
        ),
      ),
    );
  }
}

/// Набор иконок приложения.
///
/// Значения — `const`, поэтому иконку можно класть в списки `const` и в
/// дефолтные параметры виджетов без лишних аллокаций.
class AppIcons {
  const AppIcons._();

  static const play = _Icon.play;
  static const pause = _Icon.pause;
  static const skipNext = _Icon.skipNext;
  static const skipPrev = _Icon.skipPrev;
  static const shuffle = _Icon.shuffle;
  static const repeat = _Icon.repeat;
  static const repeatOne = _Icon.repeatOne;

  static const search = _Icon.search;
  static const home = _Icon.home;
  static const library = _Icon.library;
  static const stats = _Icon.stats;
  static const settings = _Icon.settings;
  static const gear = _Icon.gear;
  static const systemUpdate = _Icon.systemUpdate;

  static const back = _Icon.back;
  static const close = _Icon.close;
  static const more = _Icon.more;
  static const plus = _Icon.plus;
  static const check = _Icon.check;
  static const chevronRight = _Icon.chevronRight;
  static const chevronDown = _Icon.chevronDown;

  static const download = _Icon.download;
  static const downloadDone = _Icon.downloadDone;
  static const delete = _Icon.delete;
  static const share = _Icon.share;

  static const heart = _Icon.heart;
  static const heartFilled = _Icon.heartFilled;
  static const thumbDown = _Icon.thumbDown;
  static const bell = _Icon.bell;

  static const queue = _Icon.queue;
  static const lyrics = _Icon.lyrics;
  static const radio = _Icon.radio;
  static const musicNote = _Icon.musicNote;

  static const clock = _Icon.clock;
  static const storage = _Icon.storage;
  static const warning = _Icon.warning;
  static const sync = _Icon.sync;
  static const sparkles = _Icon.sparkles;
  static const volume = _Icon.volume;
}

extension SkinSectionIcons on SkinSection {
  AppIconData get icon => switch (this) {
        SkinSection.home => AppIcons.home,
        SkinSection.search => AppIcons.search,
        SkinSection.library => AppIcons.library,
        SkinSection.stats => AppIcons.stats,
      };
}

/// Системный шрифт для Unicode-запасников. Не Material Icons: иконка должна
/// остаться белой на чёрном даже там, где иконочный шрифт не подгрузился.
const String _sysFont = 'sans-serif';

/// Внутреннее перечисление: наружу торчат только константы [AppIcons].
///
/// Глифы — BMP-символы (без эмодзи): эмодзи рисуются цветными и выбиваются
/// из монохромного iPod, а геометрические символы остаются белыми на чёрном.
/// Символ указан комментарием справа — `IconData` требует константного
/// codePoint, вычислить его из литерала нельзя.
enum _Icon implements AppIconData {
  // Транспорт — крупный кегль, их касаются пальцем.
  play(IconData(0x25B6, fontFamily: _sysFont), 28), // ▶
  pause(IconData(0x23F8, fontFamily: _sysFont), 28), // ⏸
  skipNext(IconData(0x23ED, fontFamily: _sysFont), 26), // ⏭
  skipPrev(IconData(0x23EE, fontFamily: _sysFont), 26), // ⏮
  shuffle(IconData(0x21C4, fontFamily: _sysFont), 22), // ⇄
  repeat(IconData(0x21BB, fontFamily: _sysFont), 22), // ↻
  repeatOne(IconData(0x21BA, fontFamily: _sysFont), 22), // ↺

  // Навигация.
  search(IconData(0x2315, fontFamily: _sysFont), 22), // ⌕
  home(IconData(0x2302, fontFamily: _sysFont), 24), // ⌂
  library(IconData(0x2630, fontFamily: _sysFont), 24), // ☰
  stats(IconData(0x25A5, fontFamily: _sysFont), 24), // ▥
  settings(IconData(0x2699, fontFamily: _sysFont), 22), // ⚙
  gear(IconData(0x2699, fontFamily: _sysFont), 22), // ⚙
  systemUpdate(IconData(0x21C5, fontFamily: _sysFont), 22), // ⇅

  back(IconData(0x2039, fontFamily: _sysFont), 20), // ‹
  close(IconData(0x2715, fontFamily: _sysFont), 20), // ✕
  more(IconData(0x22EF, fontFamily: _sysFont), 20), // ⋯
  plus(IconData(0x002B, fontFamily: _sysFont), 20), // +
  check(IconData(0x2713, fontFamily: _sysFont), 18), // ✓
  chevronRight(IconData(0x203A, fontFamily: _sysFont), 20), // ›
  chevronDown(IconData(0x2304, fontFamily: _sysFont), 20), // ⌄

  // Файлы.
  download(IconData(0x21E9, fontFamily: _sysFont), 22), // ⇩
  downloadDone(IconData(0x2913, fontFamily: _sysFont), 22), // ⤓
  delete(IconData(0x232B, fontFamily: _sysFont), 20), // ⌫
  share(IconData(0x2191, fontFamily: _sysFont), 20), // ↑

  // Реакции.
  heart(IconData(0x2661, fontFamily: _sysFont), 22), // ♡
  heartFilled(IconData(0x2665, fontFamily: _sysFont), 22), // ♥
  thumbDown(IconData(0x261F, fontFamily: _sysFont), 20), // ☟
  bell(IconData(0x2606, fontFamily: _sysFont), 20), // ☆ — подписка на артиста

  // Музыка.
  queue(IconData(0x2261, fontFamily: _sysFont), 20), // ≡
  lyrics(IconData(0x266A, fontFamily: _sysFont), 20), // ♪
  radio(IconData(0x25C9, fontFamily: _sysFont), 20), // ◉
  musicNote(IconData(0x266A, fontFamily: _sysFont), 20), // ♪

  // Служебные.
  clock(IconData(0x25F7, fontFamily: _sysFont), 18), // ◷
  storage(IconData(0x25A6, fontFamily: _sysFont), 20), // ▦
  warning(IconData(0x26A0, fontFamily: _sysFont), 20), // ⚠
  sync(IconData(0x27F3, fontFamily: _sysFont), 20), // ⟳
  sparkles(IconData(0x2726, fontFamily: _sysFont), 20), // ✦
  volume(IconData(0x223F, fontFamily: _sysFont), 20); // ∿

  const _Icon(this.glyph, this.size);

  /// Запасной глиф: рисуется системным шрифтом, если для иконки нет painter'а.
  @override
  final IconData glyph;

  @override
  final double size;
}

/// Рисует глиф в нормализованной коробке 24×24: так один и тот же код
/// одинаково работает и на 16 px, и на 96 px.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.style,
    required this.color,
    required this.strokeScale,
  });

  final AppIconData glyph;
  final IconStyle style;
  final Color color;
  final double strokeScale;

  static const _c = Offset(12, 12);

  @override
  void paint(Canvas canvas, Size size) {
    final box = size.shortestSide;
    if (box <= 0) return;
    canvas.save();
    canvas.translate((size.width - box) / 2, (size.height - box) / 2);
    canvas.scale(box / 24);
    final done = _paint(canvas);
    canvas.restore();
    // Нет painter'а — рисуем Unicode-запасник, чтобы действие никогда не
    // осталось без значка.
    if (!done) _paintFallback(canvas, size);
  }

  bool get _ipod => style == IconStyle.ipod;

  /// Тонкая линия со скруглёнными концами (iOS) либо жирная заливка (iPod).
  Paint _line([double w = 1.8]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * (_ipod ? 1.35 : 1) * strokeScale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  Paint _solid() => Paint()
    ..style = PaintingStyle.fill
    ..color = color;

  /// Тон без цвета — для «приглушённых» деталей глифа.
  Paint _faint([double k = 0.45]) => Paint()
    ..style = PaintingStyle.fill
    ..color = color.withValues(alpha: color.a * k);

  static Path _ring(double outer, double inner) => _ringAt(_c, outer, inner);

  /// Кольцо с дыркой: правильный способ вырезать середину, когда цвет фона
  /// неизвестен (монохромный iPod рисуется на чём угодно поверх себя).
  static Path _ringAt(Offset c, double outer, double inner) => Path()
    ..addOval(Rect.fromCircle(center: c, radius: outer))
    ..addOval(Rect.fromCircle(center: c, radius: inner))
    ..fillType = PathFillType.evenOdd;

  static Path _star(double cx, double cy, double r) => Path()
    ..moveTo(cx, cy - r)
    ..quadraticBezierTo(cx + r * 0.16, cy - r * 0.16, cx + r, cy)
    ..quadraticBezierTo(cx + r * 0.16, cy + r * 0.16, cx, cy + r)
    ..quadraticBezierTo(cx - r * 0.16, cy + r * 0.16, cx - r, cy)
    ..quadraticBezierTo(cx - r * 0.16, cy - r * 0.16, cx, cy - r)
    ..close();

  static Path _heart() => Path()
    ..moveTo(12, 20.6)
    ..cubicTo(3.6, 15.3, 3.2, 9.8, 6.2, 7.3)
    ..cubicTo(8.5, 5.5, 11.1, 6.5, 12, 8.4)
    ..cubicTo(12.9, 6.5, 15.5, 5.5, 17.8, 7.3)
    ..cubicTo(20.8, 9.8, 20.4, 15.3, 12, 20.6)
    ..close();

  /// Дуга с «головой» стрелки на конце — основа повтора, shuffle и синхронизации.
  void _arcArrow(Canvas c, Paint p, double start, double sweep, double radius) {
    c.drawArc(
      Rect.fromCircle(center: _c, radius: radius),
      start,
      sweep,
      false,
      p,
    );
    final n = Offset(math.cos(start), math.sin(start));
    final t = Offset(-n.dy, n.dx);
    final tip = _c + n * radius;
    c.drawLine(tip, tip + t * 3.6 + n * 2.4, p);
    c.drawLine(tip, tip + t * 3.6 - n * 2.4, p);
  }

  /// Строчки списка: iPod рисует их прямоугольниками, iOS — линиями.
  void _bars(Canvas c, List<Rect> rects, double radius) {
    for (final r in rects) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
      c.drawRRect(rr, _ipod ? _solid() : _line(1.6));
    }
  }

  bool _paint(Canvas c) {
    switch (glyph) {
      // ─── Транспорт ────────────────────────────────────────────────────────
      case _Icon.play:
        final p = Path()
          ..moveTo(9, 6.2)
          ..lineTo(18.4, 11.3)
          ..quadraticBezierTo(19.2, 12, 18.4, 12.7)
          ..lineTo(9, 17.8)
          ..quadraticBezierTo(8, 18.4, 8, 17.2)
          ..lineTo(8, 6.8)
          ..quadraticBezierTo(8, 5.6, 9, 6.2)
          ..close();
        c.drawPath(p, _ipod ? _solid() : _line(2));
        return true;

      case _Icon.pause:
        for (final x in [8.8, 12.8]) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 5.6, 2.4, 12.8),
              Radius.circular(_ipod ? 0.6 : 1.1),
            ),
            _solid(),
          );
        }
        return true;

      case _Icon.skipNext:
        _bar(c, 16.4, 6.2, 2.2, 11.6);
        _triangle(c, 7.0, 12, 5.4);
        return true;

      case _Icon.skipPrev:
        _bar(c, 5.4, 6.2, 2.2, 11.6);
        _triangleRight(c, 9.6, 12, 5.4);
        return true;

      case _Icon.shuffle:
        for (final flip in [false, true]) {
          final top = flip;
          final y = top ? 7.5 : 16.5;
          c.drawPath(
            Path()
              ..moveTo(4, y)
              ..lineTo(7, y)
              ..cubicTo(11, y, 11, top ? 16.5 : 7.5, 15, top ? 16.5 : 7.5)
              ..lineTo(17.5, top ? 16.5 : 7.5),
            _line(1.7),
          );
          final ty = top ? 16.5 : 7.5;
          c.drawLine(
            Offset(14.6, ty - 3),
            Offset(17.5, ty),
            _line(1.7),
          );
          c.drawLine(
            Offset(14.6, ty + 3),
            Offset(17.5, ty),
            _line(1.7),
          );
        }
        return true;

      case _Icon.repeat:
      case _Icon.repeatOne:
        _arcArrow(c, _line(1.9), -2.1, 4.9, 6.6);
        if (glyph == _Icon.repeatOne) {
          // «1» двумя штрихами — текст в painter'е стоил бы дороже, а выглядел бы
          // тем же.
          c.drawLine(const Offset(11.6, 9.6), const Offset(11.6, 14.8), _line(1.7));
          c.drawLine(const Offset(10.2, 11), const Offset(11.6, 9.6), _line(1.7));
        } else {
          c.drawCircle(_c, 1.6, _faint(0.8));
        }
        return true;

      // ─── Навигация ────────────────────────────────────────────────────────
      case _Icon.search:
        if (_ipod) {
          c.drawCircle(const Offset(10.4, 10.4), 6.4, _solid());
          c.drawLine(const Offset(15, 15), const Offset(19.8, 19.8), _line(3.6));
        } else {
          c.drawCircle(const Offset(10.4, 10.4), 6.3, _line());
          c.drawLine(const Offset(15, 15), const Offset(20, 20), _line());
        }
        return true;

      case _Icon.home:
        if (_ipod) {
          c.drawPath(
            Path()
              ..moveTo(12, 3.2)
              ..lineTo(21.4, 11)
              ..lineTo(18.6, 11)
              ..lineTo(18.6, 20.4)
              ..lineTo(5.4, 20.4)
              ..lineTo(5.4, 11)
              ..lineTo(2.6, 11)
              ..close(),
            _solid(),
          );
        } else {
          c.drawPath(
            Path()
              ..moveTo(3.2, 11.2)
              ..lineTo(12, 4.2)
              ..lineTo(20.8, 11.2),
            _line(),
          );
          c.drawPath(
            Path()
              ..moveTo(5.6, 10.2)
              ..lineTo(5.6, 19.6)
              ..lineTo(18.4, 19.6)
              ..lineTo(18.4, 10.2),
            _line(),
          );
        }
        return true;

      case _Icon.library:
        // Стопка «пластинок» вертикальными колонками: на монохромном экране
        // это читается как полка с дисками, а не как список строк.
        _bars(
          c,
          const [
            Rect.fromLTWH(4.4, 5.4, 4.2, 13.2),
            Rect.fromLTWH(9.9, 5.4, 4.2, 13.2),
            Rect.fromLTWH(15.4, 8.2, 4.2, 10.4),
          ],
          1,
        );
        return true;

      case _Icon.stats:
        _bars(
          c,
          const [
            Rect.fromLTWH(4.6, 12.4, 3.6, 7.2),
            Rect.fromLTWH(10.2, 7.6, 3.6, 12),
            Rect.fromLTWH(15.8, 4, 3.6, 15.6),
          ],
          1.2,
        );
        return true;

      case _Icon.settings:
      case _Icon.gear:
        final p = _line(_ipod ? 2.4 : 1.7);
        final teeth = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          teeth
            ..moveTo(12 + d.dx * 6.4, 12 + d.dy * 6.4)
            ..lineTo(12 + d.dx * 9, 12 + d.dy * 9);
        }
        c.drawPath(teeth, p);
        c.drawPath(_ring(7.6, _ipod ? 5.4 : 6.4), _ipod ? _solid() : _line(1.7));
        c.drawCircle(_c, 2.4, _ipod ? _solid() : _line(1.7));
        return true;

      case _Icon.back:
        c.drawLine(const Offset(19, 12), const Offset(5.6, 12), _line(1.9));
        c.drawPath(
          Path()
            ..moveTo(11.4, 6.2)
            ..lineTo(5.6, 12)
            ..lineTo(11.4, 17.8),
          _line(1.9),
        );
        return true;

      case _Icon.close:
        c.drawLine(const Offset(6.4, 6.4), const Offset(17.6, 17.6), _line(2));
        c.drawLine(const Offset(17.6, 6.4), const Offset(6.4, 17.6), _line(2));
        return true;

      case _Icon.more:
        for (final x in <double>[6.2, 12, 17.8]) {
          c.drawCircle(Offset(x, 12), _ipod ? 1.9 : 1.5, _solid());
        }
        return true;

      case _Icon.plus:
        c.drawLine(const Offset(12, 5.4), const Offset(12, 18.6), _line(2));
        c.drawLine(const Offset(5.4, 12), const Offset(18.6, 12), _line(2));
        return true;

      case _Icon.check:
        c.drawPath(
          Path()
            ..moveTo(5.2, 12.4)
            ..lineTo(10.2, 17.4)
            ..lineTo(18.8, 6.6),
          _line(2.2),
        );
        return true;

      case _Icon.chevronRight:
        c.drawPath(
          Path()
            ..moveTo(9.6, 5.6)
            ..lineTo(16, 12)
            ..lineTo(9.6, 18.4),
          _line(2),
        );
        return true;

      case _Icon.chevronDown:
        c.drawPath(
          Path()
            ..moveTo(5.6, 9.6)
            ..lineTo(12, 16)
            ..lineTo(18.4, 9.6),
          _line(2),
        );
        return true;

      // ─── Файлы ────────────────────────────────────────────────────────────
      case _Icon.download:
        _downArrow(c, 15.4);
        c.drawPath(
          Path()
            ..moveTo(4.4, 17.6)
            ..lineTo(4.4, 19.8)
            ..lineTo(19.6, 19.8)
            ..lineTo(19.6, 17.6),
          _line(1.8),
        );
        return true;

      case _Icon.downloadDone:
        _downArrow(c, 13.2);
        c.drawPath(
          Path()
            ..moveTo(8.2, 15.6)
            ..lineTo(11, 18.2)
            ..lineTo(16.6, 11.6),
          _line(1.8),
        );
        c.drawPath(
          Path()
            ..moveTo(4.4, 17.6)
            ..lineTo(4.4, 19.8)
            ..lineTo(19.6, 19.8)
            ..lineTo(19.6, 17.6),
          _line(1.8),
        );
        return true;

      case _Icon.delete:
        c.drawLine(const Offset(4.6, 7.2), const Offset(19.4, 7.2), _line(1.8));
        c.drawPath(
          Path()
            ..moveTo(9.6, 7.2)
            ..lineTo(9.6, 4.8)
            ..lineTo(14.4, 4.8)
            ..lineTo(14.4, 7.2),
          _line(1.6),
        );
        c.drawPath(
          Path()
            ..moveTo(6.6, 7.2)
            ..lineTo(7.6, 19.6)
            ..lineTo(16.4, 19.6)
            ..lineTo(17.4, 7.2),
          _line(1.8),
        );
        if (_ipod) {
          c.drawLine(const Offset(10.2, 10.6), const Offset(10.5, 16.6), _line(1.6));
          c.drawLine(const Offset(13.8, 10.6), const Offset(13.5, 16.6), _line(1.6));
        }
        return true;

      case _Icon.share:
        c.drawPath(
          Path()
            ..moveTo(6.4, 10.4)
            ..lineTo(6.4, 19.6)
            ..lineTo(17.6, 19.6)
            ..lineTo(17.6, 10.4),
          _line(1.8),
        );
        c.drawLine(const Offset(12, 15.4), const Offset(12, 4.6), _line(1.8));
        c.drawPath(
          Path()
            ..moveTo(7.8, 8.4)
            ..lineTo(12, 4.2)
            ..lineTo(16.2, 8.4),
          _line(1.8),
        );
        return true;

      // ─── Реакции ──────────────────────────────────────────────────────────
      case _Icon.heart:
        c.drawPath(_heart(), _line(1.8));
        return true;

      case _Icon.heartFilled:
        c.drawPath(_heart(), _solid());
        return true;

      case _Icon.thumbDown:
        // Тот же контур сердца, перевёрнутый: глиф остаётся узнаваемым, а код
        // не раздувается второй кривой.
        c.save();
        c
          ..translate(24, 24)
          ..rotate(math.pi);
        c.drawPath(_heart(), _ipod ? _solid() : _line(1.8));
        c.restore();
        return true;

      // ─── Музыка ───────────────────────────────────────────────────────────
      case _Icon.queue:
        _bars(
          c,
          const [
            Rect.fromLTWH(8.6, 6.8, 11, 1.9),
            Rect.fromLTWH(8.6, 11, 11, 1.9),
            Rect.fromLTWH(8.6, 15.2, 7, 1.9),
          ],
          0.9,
        );
        _triangle(c, 3.2, 12, 4.6);
        return true;

      case _Icon.lyrics:
        _bars(
          c,
          const [
            Rect.fromLTWH(4, 6.4, 13, 1.9),
            Rect.fromLTWH(4, 10.4, 10, 1.9),
          ],
          0.9,
        );
        _note(c, const Offset(16.6, 17.4), 1);
        return true;

      case _Icon.radio:
        const dial = Offset(12, 13.4);
        c.drawLine(const Offset(15.8, 6.6), const Offset(19.6, 3.4), _line(1.7));
        if (_ipod) {
          // Сплошной диск с вырезанным центром: заливка «поверх себя» дала бы
          // белый круг без намёка на динамик.
          c.drawPath(_ringAt(dial, 7, 2.4), _solid());
        } else {
          c.drawCircle(dial, 7, _line(1.8));
          c.drawCircle(dial, 2.4, _faint(0.5));
        }
        return true;

      case _Icon.musicNote:
        _note(c, const Offset(8, 17.6), 1.25);
        return true;

      // ─── Служебные ────────────────────────────────────────────────────────
      case _Icon.clock:
        // Стрелки рисуются в обоих стилях: сплошной диск без стрелок — это
        // кружок, а не часы.
        c.drawPath(_ring(8.4, _ipod ? 6.6 : 7.4), _ipod ? _solid() : _line(1.8));
        c.drawLine(const Offset(12, 12), const Offset(12, 7.4), _line(1.7));
        c.drawLine(const Offset(12, 12), const Offset(15.6, 13.6), _line(1.7));
        return true;

      case _Icon.storage:
        // Три «слоя» с небольшим смещением — читается как стопка дисков.
        _bars(
          c,
          const [
            Rect.fromLTWH(4, 5.6, 16, 3.4),
            Rect.fromLTWH(4, 10.4, 16, 3.4),
            Rect.fromLTWH(4, 15.2, 16, 3.4),
          ],
          1,
        );
        return true;

      case _Icon.warning:
        c.drawPath(
          Path()
            ..moveTo(12, 4)
            ..lineTo(21.4, 19.8)
            ..lineTo(2.6, 19.8)
            ..close(),
          _ipod ? _solid() : _line(1.8),
        );
        if (!_ipod) {
          c.drawLine(const Offset(12, 10), const Offset(12, 14.6), _line(1.7));
          c.drawCircle(const Offset(12, 17.2), 1, _solid());
        }
        return true;

      case _Icon.sync:
        // Две дуги строго в полоборота друг от друга и почти без нахлёста:
        // при большем перекрытии стрелки сливаются в безформенное кольцо.
        _arcArrow(c, _line(1.8), -2.55, 3.9, 6.8);
        _arcArrow(c, _line(1.8), 0.59, 3.9, 6.8);
        return true;

      case _Icon.sparkles:
        c.drawPath(_star(9.6, 9.6, 7), _ipod ? _solid() : _line(1.5));
        c.drawPath(_star(17.4, 17, 3.6), _ipod ? _solid() : _line(1.4));
        return true;

      case _Icon.volume:
        c.drawPath(
          Path()
            ..moveTo(4.2, 9.4)
            ..lineTo(8, 9.4)
            ..lineTo(12.4, 5.4)
            ..lineTo(12.4, 18.6)
            ..lineTo(8, 14.6)
            ..lineTo(4.2, 14.6)
            ..close(),
          _ipod ? _solid() : _line(1.7),
        );
        c.drawArc(
          Rect.fromCircle(center: const Offset(11.4, 12), radius: 5),
          -0.9,
          1.8,
          false,
          _line(1.7),
        );
        c.drawArc(
          Rect.fromCircle(center: const Offset(11.4, 12), radius: 8),
          -0.9,
          1.8,
          false,
          _line(1.6),
        );
        return true;
    }
    // Сюда попадём, только если у [glyph] нет painter'а (например, кто-то
    // добавит иконку в enum, забыв нарисовать её) — тогда сработает запасник.
    return false;
  }

  void _bar(Canvas c, double x, double y, double w, double h) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(_ipod ? 0.6 : 1),
      ),
      _solid(),
    );
  }

  /// Треугольник «вправо» с закруглёнными углами: углы скругляет обводка со
  /// StrokeJoin.round, поэтому один и тот же путь годится для обоих скинов.
  void _triangle(Canvas c, double x, double cy, double half) {
    c.drawPath(
      Path()
        ..moveTo(x, cy - half)
        ..lineTo(x + half * 1.65, cy)
        ..lineTo(x, cy + half)
        ..close(),
      _ipod ? _solid() : _line(1.9),
    );
  }

  /// Треугольник, «повёрнутый» остриями влево (указатель назад).
  void _triangleRight(Canvas c, double x, double cy, double half) {
    c.drawPath(
      Path()
        ..moveTo(x, cy - half)
        ..lineTo(x - half * 1.65, cy)
        ..lineTo(x, cy + half)
        ..close(),
      _ipod ? _solid() : _line(1.9),
    );
  }

  void _downArrow(Canvas c, double yTip) {
    c.drawLine(const Offset(12, 4.4), Offset(12, yTip - 0.2), _line(2));
    c.drawPath(
      Path()
        ..moveTo(7.6, yTip - 4.6)
        ..lineTo(12, yTip)
        ..lineTo(16.4, yTip - 4.6),
      _line(2),
    );
  }

  /// Нотный знак: штиль + залитая головка, слегка повёрнутая (как в нотах).
  void _note(Canvas c, Offset headCenter, double k) {
    final rx = 3.5 * k;
    final ry = 2.7 * k;
    final stemX = headCenter.dx + rx - 0.8;
    c.save();
    c.translate(headCenter.dx, headCenter.dy);
    c.rotate(-0.32);
    c.translate(-headCenter.dx, -headCenter.dy);
    c.drawOval(
      Rect.fromCenter(
        center: headCenter,
        width: rx * 2,
        height: ry * 2,
      ),
      _solid(),
    );
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(stemX, headCenter.dy - 9.6 * k, stemX + 1.6 * k, headCenter.dy),
        Radius.circular(0.8 * k),
      ),
      _solid(),
    );
  }

  /// Аварийный путь: если для иконки нет painter'а — показываем
  /// Unicode-глиф системным шрифтом.
  void _paintFallback(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(glyph.glyph.codePoint),
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: size.height * 0.85,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.style != style ||
      old.color != color ||
      old.strokeScale != strokeScale;
}