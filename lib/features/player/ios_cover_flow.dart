import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/artwork.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart';
import '../../domain/models/track.dart';

/// Сколько соседей рисуем с каждой стороны от текущей карточки.
///
/// Две цифры, а не «сколько влезет»: на длинной радио-очереди (сотни треков)
/// фонарей по краям заметно дороже центральной пятёрки, а видимой разницы
/// пользователь не видит — до дальних обложек палец всё равно не дотянется.
const int kCoverFlowNeighbors = 2;

/// Индексы карточек, которые имеет смысл рисовать: текущий и до [maxNeighbors]
/// соседей с каждой стороны.
///
/// Вынесено отдельной чистой функцией, потому что это ровно то решение, из-за
/// которого Cover Flow дорожает на длинной очереди (см. §10 дизайн-документа
/// «риски»). Проверяется обычным тестом без насоса кадров.
List<int> coverFlowWindow({
  required int current,
  required int count,
  int maxNeighbors = kCoverFlowNeighbors,
}) {
  if (count <= 0) return const [];
  final n = maxNeighbors < 0 ? 0 : maxNeighbors;
  final c = current.clamp(0, count - 1);
  final from = (c - n).clamp(0, count - 1);
  final to = (c + n).clamp(0, count - 1);
  return [for (var i = from; i <= to; i++) i];
}

/// Индекс, в который «встаёт» поток при текущем смещении.
///
/// [offset] измеряется в карточках: 2.4 — между вторым и третьим треком.
/// [velocity] — скорость в карточках в секунду, положительная означает «вперёд».
/// Пока скорость меньше [fling], поток просто округляется до ближайшей
/// карточки; быстрый флинг перешагивает ровно одну карточку, даже если палец
/// прошёл меньше половины — так очередь листается «в одну маху», как в iOS.
///
/// Границы очереди зажимаются, а не закольцовываются: бесшовный переход через
/// край пользователь принял бы за глюк, а на радио-очереди он и вовсе не
/// имеет смысла — там хвоста может не быть.
int coverFlowIndexForOffset({
  required double offset,
  required int count,
  double velocity = 0,
  double fling = 1.2,
}) {
  if (count <= 0) return 0;
  if (count == 1) return 0;
  var target = offset.round();
  if (velocity.abs() >= fling) {
    target = velocity > 0 ? offset.floor() + 1 : offset.ceil() - 1;
  }
  return target.clamp(0, count - 1);
}

/// Обложки очереди с прокруткой свайпом (Cover Flow) — центральная карточка
/// текущий трек, соседи повёрнуты в 3D.
///
/// Виджет чистый: принимает список, текущий индекс и колбэк, сам ничего не
/// знает про плеер и не дёргает провайдеры. Логику переключения трека держит
/// экран (см. `onIndexChanged`).
class IosCoverFlow extends StatefulWidget {
  const IosCoverFlow({
    super.key,
    required this.tokens,
    required this.items,
    required this.index,
    required this.onIndexChanged,
    this.direction = 1,
    this.maxNeighbors = kCoverFlowNeighbors,
  });

  final DesignTokens tokens;
  final List<Track> items;

  /// Текущий трек; вне диапазона (подстановка, радио) — прижимается к краю.
  final int index;

  /// Пользователь выбрал другую карточку (свайпом или тапом по соседу).
  final ValueChanged<int> onIndexChanged;

  /// Направление последней смены трека: 1 — вперёд, -1 — назад.
  final int direction;

  final int maxNeighbors;

  @override
  State<IosCoverFlow> createState() => _IosCoverFlowState();
}

class _IosCoverFlowState extends State<IosCoverFlow>
    // Два контроллера (прокрутка и подъём обложки), поэтому нужен
    // TickerProviderStateMixin, а не SingleTickerProviderStateMixin.
    with TickerProviderStateMixin {
  /// Смещение потока в карточках: 0 — первый трек, 2.4 — между вторым и третьим.
  ///
  /// Именно контроллер, а не поле + setState: пока идёт свайп или анимация
  /// докатки, `ListenableBuilder` ниже перерисовывает только сам ряд карточек.
  /// Создаётся в initState — `vsync: this` нельзя передать в инициализаторе
  /// поля до конца lifec'икла.
  late final AnimationController _scroll;

  /// Подъём по Y входящей карточки при смене трека кнопкой/радио.
  ///
  /// Отдельный от [_scroll]: свайп уже показывает смену горизонтальным сдвигом,
  /// и если бы он ещё и дублировался вертикальным, две анимации наезжали бы
  /// друг на друга. Кнопка «вперёд» поднимает обложку снизу — это и есть
  /// отличие от свайпа.
  late final AnimationController _lift;

  /// Сколько пикселей сдвигает поток на одну карточку. Заполняется при
  /// раскладке: без размеров перевод жеста в карточки невозможен.
  double _pageExtent = 0;

  /// Куда мы сами предложили перейти и ждём подтверждения от экрана.
  /// Нужен, чтобы вернуть поток на место, если экран выбор отверг.
  int? _pending;

  /// Индекс, к которому пришли именно свайпом: для него подъём не запускаем.
  int? _fromSwipe;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController.unbounded(vsync: this);
    _lift = AnimationController(
      vsync: this,
      duration: widget.tokens.motionDuration,
    );
    _scroll.value = _clampIndex(widget.index).toDouble();
    _scroll.addStatusListener(_onScrollDone);
  }

  @override
  void didUpdateWidget(covariant IosCoverFlow old) {
    super.didUpdateWidget(old);
    final count = widget.items.length;
    if (count == 0) return;
    final target = _clampIndex(widget.index).toDouble();

    // Очередь могла укоротиться (радио переключилось) — тогда не анимируем,
    // а сразу встаём в допустимые границы.
    final maxOffset = (count - 1).toDouble();
    if (_scroll.value > maxOffset) {
      _scroll.value = maxOffset;
    }

    if (_scroll.value != target) {
      // Смена трека не свайпом: поднимаем новую карточку снизу/сверху.
      if (widget.index != old.index && _fromSwipe != _clampIndex(widget.index)) {
        _lift.duration = widget.tokens.motionDuration;
        _lift.forward(from: 0);
      }
      _animateTo(target);
    }
    if (_fromSwipe == _clampIndex(widget.index)) _fromSwipe = null;
    if (_pending == _clampIndex(widget.index)) _pending = null;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _lift.dispose();
    super.dispose();
  }

  int _clampIndex(int i) =>
      widget.items.isEmpty ? 0 : i.clamp(0, widget.items.length - 1);

  void _animateTo(double target) {
    _scroll.animateTo(
      target,
      duration: widget.tokens.motionDuration,
      curve: widget.tokens.motionCurve,
    );
  }

  /// Докатка закончилась, а экран так и не подтвердил выбор — значит, трек
  /// не нашёлся в очереди (радио подменило очередь). Возвращаем поток туда,
  /// где он соответствует реальному текущему треку.
  void _onScrollDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || _pending == null) return;
    _pending = null;
    final target = _clampIndex(widget.index).toDouble();
    if ((_scroll.value - target).abs() > 0.01) _scroll.value = target;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_pageExtent <= 0) return;
    final maxOffset = (widget.items.length - 1).toDouble();
    final next = _scroll.value - d.delta.dx / _pageExtent;
    _scroll.value = next.clamp(0.0, maxOffset);
  }

  void _dragEnd(DragEndDetails d) {
    if (_pageExtent <= 0) return;
    // Палец влево (dx < 0) — следующий трек, поэтому знак минус.
    final velocity = -d.velocity.pixelsPerSecond.dx / _pageExtent;
    _goTo(coverFlowIndexForOffset(
      offset: _scroll.value,
      count: widget.items.length,
      velocity: velocity,
    ));
  }

  /// Единая точка перехода: докатываем поток и сообщаем экрану выбор.
  void _goTo(int index, {bool fromSwipe = false}) {
    final target = index.clamp(0, widget.items.length - 1);
    _pending = target;
    if (fromSwipe) _fromSwipe = target;
    _animateTo(target.toDouble());
    if (target != _clampIndex(widget.index)) widget.onIndexChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return EmptyState(
        tokens: widget.tokens,
        icon: AppIcons.musicNote,
        title: 'Очередь пуста',
        subtitle: 'Включите трек — и обложки очереди появятся здесь',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Центральная карточка — «обложка сейчас играет»: 72 % ширины экрана
        // (как в iOS), но не выше доступной высоты, иначе на низком экране
        // ряд управления уедет за пределы.
        final card = math.min(c.maxWidth * _centerShare, c.maxHeight);
        _pageExtent = card * _stepShare;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Только горизонталь: вертикальный жест (свайп вниз — закрыть)
          // должен добраться до родителя, и арбитраж решает его сам.
          onHorizontalDragStart: (_) => _scroll.stop(),
          onHorizontalDragUpdate: _dragUpdate,
          onHorizontalDragEnd: _dragEnd,
          child: Center(
            child: SizedBox(
              width: c.maxWidth,
              // Запас по высоте: повёрнутые соседи выходят за габариты
              // центральной карточки, и без запаса их срезает родитель.
              height: card + card * _heightSlack,
              child: ListenableBuilder(
                listenable: Listenable.merge([_scroll, _lift]),
                builder: (context, _) => _deck(card),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _deck(double card) {
    final count = widget.items.length;
    final offset = _scroll.value.clamp(0.0, (count - 1).toDouble());
    final visible = coverFlowWindow(
      current: offset.round(),
      count: count,
      maxNeighbors: widget.maxNeighbors,
    );
    return Stack(
      alignment: Alignment.center,
      // Карточки уходят за края экрана — обрезать их нельзя, иначе сосед
      // исчезает ровно в тот момент, когда до него хочется дотянуться.
      clipBehavior: Clip.none,
      children: [for (final i in visible) _card(i, offset, card)],
    );
  }

  Widget _card(int index, double offset, double card) {
    final track = widget.items[index];
    final rel = index - offset; // 0 — центр, ±1 — сосед, ±2 — дальний
    final depth = rel.abs();

    final matrix = Matrix4.identity()
      // Перспектива: без неё поворот соседей выглядит как плоская раскладка.
      ..setEntry(3, 2, _perspective)
      // Сосед справа (rel > 0) поворачивается правым краем «от» зрителя, и
      // его ближний к центру край выходит вперёд — так же, как в iOS.
      ..rotateY(rel * _turn)
      // ...и разводится по X уже в повёрнутой системе: получается веер,
      // сходящийся к точке схода, а не просто сдвинутая копия.
      ..translateByDouble(rel * card * _stepShare, 0, 0, 1)
      // Дальние карточки уходят в глубину — иначе они того же размера, что
      // центральная, и глаз не понимает, где «сейчас играет».
      ..translateByDouble(0, 0, -depth * card * _depthShare, 1);

    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(widget.tokens.radiusLg),
      child: SizedBox.square(
        dimension: card,
        child: Artwork(
          track.artworkUrl,
          size: card,
          radius: widget.tokens.radiusLg,
          seed: track.uid,
        ),
      ),
    );

    // Гасим соседей фоном скина: центр должен остаться единственным ярким
    // пятном, иначе очередь из пяти песен выглядит как каша обложек.
    if (depth > _dimEpsilon) {
      cover = Stack(
        children: [
          cover,
          Positioned.fill(
            child: ColoredBox(
              color: widget.tokens.background.withValues(
                alpha: (depth * _dimShare).clamp(0.0, _dimMax),
              ),
            ),
          ),
        ],
      );
    }

    // Текущий трек при смене кнопкой/радио поднимается по Y — см. [_lift].
    if (index == widget.index && _lift.isAnimating) {
      cover = FadeTransition(
        opacity: _lift,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, _liftEnter * widget.direction),
            end: Offset.zero,
          ).animate(_lift),
          child: ScaleTransition(
            scale: Tween<double>(begin: _liftScale, end: 1).animate(_lift),
            child: cover,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Semantics(
          image: true,
          label: track.title,
          // Тап по соседу — короткий путь к треку: не тянуться, а тыкнуть.
          child: GestureDetector(
            onTap: index == widget.index ? null : () => _goTo(index),
            child: cover,
          ),
        ),
      ),
    );
  }

  // Геометрия потока. Это константы раскладки, а не стиль: они одинаковы для
  // всех скинов (Cover Flow рисует только iOS), поэтому живут здесь, а не в
  // токенах — иначе iPod-скин получил бы пять неиспользуемых полей.

  /// Доля ширины экрана, которую занимает центральная обложка.
  static const double _centerShare = 0.72;

  /// Насколько сосед смещён и насколько «докручен» поворот (радианы).
  static const double _stepShare = 0.55;
  static const double _turn = 0.42;

  /// Коэффициент перспективы: меньше — сильнее «уход вдаль».
  static const double _perspective = 0.0012;

  /// Насколько дальний сосед уходит в глубину (доля от стороны карточки).
  static const double _depthShare = 0.22;

  /// Запас по высоте для повёрнутых карточек.
  static const double _heightSlack = 0.12;

  /// Затемнение соседей: доля от расстояния до центра, максимум [_dimMax].
  static const double _dimShare = 0.3;
  static const double _dimMax = 0.6;
  static const double _dimEpsilon = 0.03;

  /// Подъём входящей карточки: доля её высоты + стартовый масштаб.
  static const double _liftEnter = 0.45;
  static const double _liftScale = 0.92;
}