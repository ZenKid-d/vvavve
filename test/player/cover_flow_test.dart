import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/artwork.dart';
import 'package:roundds/design/tokens/ios_tokens.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/player/ios_cover_flow.dart';

/// Cover Flow: чистая логика и виджет.
///
/// Проверяем три вещи, на которых держится и скорость, и управляемость потока:
/// индекс из смещения (куда «встаёт» колода), сколько карточек вообще рисуется
/// и что происходит с пустой очередью.
void main() {
  // Токены собирают шрифт через google_fonts, которому нужен биндинг: без
  // этой строки тест печатает ошибку загрузки Inter, хотя и проходит.
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = IosTokens.instance;

  Track track(String id) => Track(
        id: id,
        title: 'Трек $id',
        artist: 'Артист',
        source: SourceType.youtube,
      );

  Future<void> pump(
    WidgetTester tester, {
    required List<Track> items,
    required int index,
    ValueChanged<int>? onIndexChanged,
    int direction = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: IosCoverFlow(
              tokens: tokens,
              items: items,
              index: index,
              direction: direction,
              onIndexChanged: onIndexChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('coverFlowIndexForOffset — индекс из смещения', () {
    test('пустая очередь — нулевой индекс', () {
      expect(coverFlowIndexForOffset(offset: 3.7, count: 0), 0);
    });

    test('один трек — всегда 0, хоть как тащи', () {
      expect(coverFlowIndexForOffset(offset: 0.4, count: 1), 0);
      expect(coverFlowIndexForOffset(offset: 0.4, count: 1, velocity: 9), 0);
    });

    test('медленное смещение округляется до ближайшей карточки', () {
      expect(coverFlowIndexForOffset(offset: 0.2, count: 10), 0);
      expect(coverFlowIndexForOffset(offset: 0.6, count: 10), 1);
      expect(coverFlowIndexForOffset(offset: 2.49, count: 10), 2);
    });

    test('быстрый флинг перешагивает ровно одну карточку', () {
      // Палец прошёл меньше половины карточки, но «флинг» — намерение листать.
      expect(
        coverFlowIndexForOffset(offset: 1.1, count: 10, velocity: 2.5),
        2,
        reason: 'вперёд',
      );
      expect(
        coverFlowIndexForOffset(offset: 1.9, count: 10, velocity: -2.5),
        1,
        reason: 'назад',
      );
    });

    test('медленное смещение скоростью флингом не считается', () {
      expect(coverFlowIndexForOffset(offset: 1.9, count: 10, velocity: 0.4), 2);
      expect(
          coverFlowIndexForOffset(offset: 1.1, count: 10, velocity: -0.4), 1);
    });

    test('края очереди зажимаются, а не закольцовываются', () {
      expect(coverFlowIndexForOffset(offset: -2, count: 5), 0);
      expect(coverFlowIndexForOffset(offset: 9, count: 5), 4);
      expect(
        coverFlowIndexForOffset(offset: 4.2, count: 5, velocity: 5),
        4,
        reason: 'флинг с последнего трека не перескакивает на первый',
      );
      expect(
        coverFlowIndexForOffset(offset: 0.2, count: 5, velocity: -5),
        0,
      );
    });
  });

  group('coverFlowWindow — сколько карточек рисуем', () {
    test('не больше пяти карточек в длинной очереди', () {
      final window = coverFlowWindow(current: 40, count: 200);
      expect(window.length, 5, reason: 'центр + по два соседа');
      expect(window, [38, 39, 40, 41, 42]);
    });

    test('у края окно короче, а не выходит за очередь', () {
      expect(coverFlowWindow(current: 0, count: 200), [0, 1, 2]);
      expect(coverFlowWindow(current: 199, count: 200), [197, 198, 199]);
    });

    test('очередь короче окна — рисуем всё, что есть', () {
      expect(coverFlowWindow(current: 0, count: 3), [0, 1, 2]);
      expect(coverFlowWindow(current: 0, count: 1), [0]);
    });

    test('пустая очередь — пустое окно', () {
      expect(coverFlowWindow(current: 0, count: 0), isEmpty);
    });

    test('индекс вне очереди зажимается', () {
      expect(coverFlowWindow(current: -1, count: 10).first, 0);
      expect(coverFlowWindow(current: 99, count: 10).last, 9);
    });
  });

  group('виджет', () {
    testWidgets('пустая очередь — пустое состояние, обложек нет',
        (tester) async {
      await pump(tester, items: const [], index: 0);

      expect(find.byType(Artwork), findsNothing);
      expect(find.text('Очередь пуста'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('рисует не больше пяти обложек на длинной очереди',
        (tester) async {
      await pump(
        tester,
        items: [for (var i = 0; i < 60; i++) track('$i')],
        index: 30,
      );

      expect(find.byType(Artwork), findsNWidgets(5));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('в центре колоды — текущий трек', (tester) async {
      final items = [for (var i = 0; i < 10; i++) track('$i')];
      await pump(tester, items: items, index: 4);

      final finder = find.byType(Artwork);
      final uids = tester
          .widgetList<Artwork>(finder)
          .map((w) => w.seed)
          .whereType<String>()
          .toList();
      expect(uids.length, 5, reason: 'центр + по два соседа');
      expect(
        uids,
        containsAll(items.sublist(2, 7).map((t) => t.uid)),
        reason: 'видны треки вокруг текущего',
      );
      expect(uids, isNot(contains(items[1].uid)),
          reason: 'дальний слева не рисуем');

      // Ближе всех к центру потока стоит обложка текущего трека.
      final centerX = tester.getCenter(find.byType(IosCoverFlow)).dx;
      final nearest = <String, double>{};
      for (var i = 0; i < uids.length; i++) {
        final dx = (tester.getRect(finder.at(i)).center.dx - centerX).abs();
        nearest[uids[i]] = dx;
      }
      final center =
          nearest.entries.reduce((a, b) => a.value <= b.value ? a : b);
      expect(center.key, items[4].uid);
    });

    testWidgets('свайп влево сообщает следующий индекс', (tester) async {
      final items = [for (var i = 0; i < 10; i++) track('$i')];
      final picked = <int>[];
      await pump(
        tester,
        items: items,
        index: 3,
        onIndexChanged: picked.add,
      );

      await tester.drag(find.byType(IosCoverFlow), const Offset(-220, 0));
      await tester.pumpAndSettle();

      expect(picked, [4], reason: 'свайп влево — следующий трек');
    });

    // Регресс на замер: при p > 0 в Flutter дальние карточки (z < 0) получали
    // w < 1 и РАСТОЛИ вместо уменьшения — центральная обложка оказывалась
    // самой узкой (замер: 259 px против 332 px у дальних). Плюс перенос по X
    // шёл после поворота, из-за чего дальние карточки схлопывались к центру и
    // перекрещивались с ближними. Теперь ширины монотонно убывают от центра.
    testWidgets('дальние обложки мельче центральной, центральная — в центре',
        (tester) async {
      final items = [for (var i = 0; i < 8; i++) track('$i')];
      await pump(tester, items: items, index: 3);

      final finder = find.byType(Artwork);
      final widthByUid = <String, double>{};
      final centreByUid = <String, double>{};
      final zoneCentre = tester.getCenter(find.byType(IosCoverFlow)).dx;
      for (var i = 0; i < finder.evaluate().length; i++) {
        final w = tester.widget<Artwork>(finder.at(i));
        final r = tester.getRect(finder.at(i));
        widthByUid[w.seed!] = r.width;
        centreByUid[w.seed!] = r.center.dx;
      }

      final centreWidth = widthByUid[items[3].uid]!;
      expect(
        centreWidth,
        greaterThan(widthByUid[items[4].uid]!),
        reason: 'сосед должен быть уже текущего',
      );
      // Соседи слева и справа равны по замеру (расхождение — только погрешность
      // float), а дальний — заметно мельче ближнего.
      expect(
        (widthByUid[items[2].uid]! - widthByUid[items[4].uid]!).abs(),
        lessThan(0.5),
        reason: 'веер симметричен',
      );
      expect(
        widthByUid[items[1].uid]!,
        lessThan(widthByUid[items[2].uid]!),
        reason: 'чем дальше от центра, тем мельче (перспектива вглубь)',
      );
      expect(
        (centreByUid[items[3].uid]! - zoneCentre).abs(),
        lessThan(1.0),
        reason: 'текущая обложка стоит ровно в центре зоны',
      );
      expect(
        centreByUid[items[2].uid]!,
        lessThan(centreByUid[items[4].uid]!),
        reason: 'левая обложка левее правой — веер не схлопывается',
      );
    });

    testWidgets('смена трека снаружи докатывает поток и поднимает обложку',
        (tester) async {
      final items = [for (var i = 0; i < 10; i++) track('$i')];
      final picked = <int>[];

      Widget build(int index) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: IosCoverFlow(
                  tokens: tokens,
                  items: items,
                  index: index,
                  direction: 1,
                  onIndexChanged: picked.add,
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1)); // как будто нажали «вперёд»
      await tester.pump(); // первый кадр анимации
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      // Экран сам индекс не менял — колода обязана остаться на текущем треке.
      expect(picked, isEmpty);
      final finder = find.byType(Artwork);
      final count = finder.evaluate().length;
      expect(count, inInclusiveRange(3, 5));

      final centerX = tester.getCenter(find.byType(IosCoverFlow)).dx;
      final nearest = <String, double>{};
      for (var i = 0; i < count; i++) {
        final w = tester.widget<Artwork>(finder.at(i));
        nearest[w.seed!] =
            (tester.getRect(finder.at(i)).center.dx - centerX).abs();
      }
      final center =
          nearest.entries.reduce((a, b) => a.value <= b.value ? a : b);
      expect(center.key, items[1].uid,
          reason: 'поток докатился до нового трека');
    });
  });
}
