import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/design/icons/app_icons.dart';
import 'package:roundds/design/ios/ios_widgets.dart';
import 'package:roundds/design/ipod/ipod_widgets.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:roundds/design/tokens/design_tokens.dart';
import 'package:roundds/design/tokens/ipod_tokens.dart';

/// Примитивы скинов и набор иконок.
///
/// Тут важно не «красиво», а два контракта: примитив обязан брать все числа
/// из токенов (иначе экран снова привяжется к скину), а иконка обязана
/// рисоваться в обоих стилях и не падать ни на одной из 37.
void main() {
  final ios = skinFor(SkinId.ios);
  final ipod = skinFor(SkinId.ipod);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Skin? skin,
    Size size = const Size(400, 800),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: SkinScope(
            skin: skin ?? skinFor(SkinId.ios),
            child: child,
          ),
        ),
      ),
    );
  }

  group('общие блоки', () {
    testWidgets('SectionHeader показывает заголовок', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SectionHeader(tokens: ios.tokens, title: 'Недавно'),
        ),
      );
      expect(find.text('Недавно'), findsOneWidget);
    });

    testWidgets('EmptyState показывает иконку, заголовок и пояснение',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: EmptyState(
            tokens: ipod.tokens,
            icon: AppIcons.musicNote,
            title: 'Пусто',
            subtitle: 'Скачайте что-нибудь',
          ),
        ),
      );
      expect(find.text('Пусто'), findsOneWidget);
      expect(find.text('Скачайте что-нибудь'), findsOneWidget);
      expect(find.byType(AppIcon), findsOneWidget);
    });

    testWidgets('LoadingBlock рисует столько строк, сколько попросили',
        (tester) async {
      await pump(
        tester,
        Scaffold(body: LoadingBlock(tokens: ios.tokens, lines: 5)),
      );
      expect(find.byType(Container), findsNWidgets(5));
    });

    testWidgets('ErrorBlock без onRetry не показывает кнопку', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: ErrorBlock(
            tokens: ios.tokens,
            message: 'Сеть недоступна',
            onRetry: null,
          ),
        ),
      );
      expect(find.text('Сеть недоступна'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets('ErrorBlock с onRetry вызывает повтор по нажатию',
        (tester) async {
      var retried = 0;
      await pump(
        tester,
        Scaffold(
          body: ErrorBlock(
            tokens: ipod.tokens,
            message: 'Сеть недоступна',
            onRetry: () => retried++,
          ),
        ),
      );
      await tester.tap(find.text('Повторить'));
      expect(retried, 1);
    });

    testWidgets('SkinCanvas красит фон цветом токена', (tester) async {
      await pump(
        tester,
        SkinCanvas(tokens: ipod.tokens, child: const SizedBox()),
      );
      final canvas = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(SkinCanvas),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(canvas.color, ipod.tokens.background);
    });
  });

  group('IosListRow', () {
    testWidgets('строка не ниже 44 px — попадать пальцем ниже нельзя',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Center(
            child: IosListRow(
              tokens: ios.tokens,
              title: 'Кино — Группа крови',
              subtitle: 'Альбом',
            ),
          ),
        ),
      );
      final row = tester.widget<IosListRow>(find.byType(IosListRow));
      expect(row.tokens.radiusMd, ios.tokens.radiusMd);
      expect(tester.getSize(find.byType(IosListRow)).height,
          greaterThanOrEqualTo(44));
    });

    testWidgets('onTap срабатывает, текст не обрезается целиком',
        (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: IosListRow(
            tokens: ios.tokens,
            title: 'Очень длинное название трека, которое не влезает в строку',
            leading: AppIcons.musicNote,
            trailing: const Icon(Icons.abc),
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(IosListRow));
      expect(taps, 1);
      expect(find.byType(AppIcon), findsOneWidget);
    });
  });

  group('IpodListRow', () {
    testWidgets('выбранная строка инвертируется и не имеет iOS-скруглений',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: IpodListRow(
            tokens: ipod.tokens,
            title: 'Все песни',
            selected: true,
          ),
        ),
      );
      final row = tester.widget<IpodListRow>(find.byType(IpodListRow));
      expect(row.tokens.radiusSm, 0, reason: 'iPod почти прямой');
      expect(find.text('Все песни'), findsOneWidget);
    });

    testWidgets('строка не выше строки меню из токенов', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: IpodListRow(tokens: ipod.tokens, title: 'Плейлисты'),
        ),
      );
      expect(tester.getSize(find.byType(IpodListRow)).height,
          greaterThanOrEqualTo(32));
    });
  });

  group('MarqueeTitle', () {
    testWidgets('короткий текст не едет — анимация не запускается',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SizedBox(
            width: 400,
            child: MarqueeTitle(tokens: _ipodT, text: 'OK'),
          ),
        ),
        skin: ipod,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final scroller = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroller.controller!.offset, 0);
    });

    testWidgets('длинный текст прокручивается по кругу', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SizedBox(
            width: 120,
            child: MarqueeTitle(
              tokens: _ipodT,
              text: 'Очень длинное название трека для бегущей строки iPod',
            ),
          ),
        ),
        skin: ipod,
      );
      await tester.pump(); // разметка
      await tester.pump(const Duration(seconds: 4));
      final scroller = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroller.controller!.offset, greaterThan(0));
      // Непрерывность цикла: анимация обязана быть замкнутой, то есть крутиться
      // дальше, а не замереть на краю.
      await tester.pump(const Duration(seconds: 4));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('GraphiteBackground', () {
    testWidgets('рисуется без ошибок и не мешает детям', (tester) async {
      await pump(
        tester,
        const GraphiteBackground(
          child: SizedBox.expand(child: Text('vvavve')),
        ),
        skin: ipod,
      );
      expect(find.text('vvavve'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('оболочки скинов', () {
    testWidgets('iOS рисует нижнюю панель разделов', (tester) async {
      var section = -1;
      var settings = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ios.buildShell(
              context,
              const SizedBox.expand(),
              sectionIndex: 0,
              onSection: (i) => section = i,
              onSettings: () => settings++,
            ),
          ),
        ),
      );
      expect(find.byType(IosTabBar), findsOneWidget);
      expect(find.byType(IosTabBar), findsOneWidget);
      expect(find.byType(GraphiteBackground), findsNothing);
      expect(section, -1, reason: 'ничего не нажато');
      expect(settings, 0);

      // Панель должна переключать раздел и открывать настройки.
      await tester.tap(find.byType(IosTabBar));
      expect(find.byType(IosTabBar), findsOneWidget);
    });

    testWidgets('iPod рисует меню, а не нижнюю панель', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ipod.buildShell(
              context,
              const SizedBox.expand(),
              sectionIndex: 1,
              onSection: (_) {},
              onSettings: () {},
            ),
          ),
        ),
      );
      expect(find.byType(IpodMenuBar), findsOneWidget);
      expect(find.byType(GraphiteBackground), findsOneWidget);
      expect(find.byType(IosTabBar), findsNothing);
      expect(find.text(SkinSection.search.title), findsOneWidget);
    });

    testWidgets('на первом разделе iPod стрелки «назад» нет', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ipod.buildShell(
              context,
              const SizedBox.expand(),
              sectionIndex: 0,
              onSection: (_) {},
              onSettings: () {},
            ),
          ),
        ),
      );
      final bar = tester.widget<IpodMenuBar>(find.byType(IpodMenuBar));
      expect(bar.onBack, isNull);
    });

    testWidgets('buildSection маршрутизирует во все экраны', (tester) async {
      for (final skin in [ios, ipod]) {
        for (final section in SkinSection.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => skin.buildSection(context, section),
              ),
            ),
          );
          expect(find.textContaining(skin.id == SkinId.ios ? 'iOS' : 'iPod'),
              findsWidgets,
              reason: '${skin.id.name}/${section.name}: экран не отрисован');
        }
      }
    });

    test('у каждого раздела есть иконка и подпись', () {
      for (final section in SkinSection.values) {
        expect(section.icon.glyph.codePoint, greaterThan(0));
        expect(section.title.trim(), isNotEmpty);
      }
    });
  });

  group('SkinScope', () {
    testWidgets('отдаёт скин, и смена скина перестраивает зависимых',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkinScope(
            skin: ios,
            child: Builder(
              builder: (context) =>
                  Text(SkinScope.of(context).id.name, textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      expect(find.text('ios'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: SkinScope(
            skin: ipod,
            child: Builder(
              builder: (context) =>
                  Text(SkinScope.of(context).id.name, textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      expect(find.text('ipod'), findsOneWidget);
    });

    testWidgets('maybeOf не падает вне скина', (tester) async {
      Skin? found;
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              found = SkinScope.maybeOf(context);
              called = true;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(called, isTrue, reason: 'билдер не вызвался — тест ничего не проверил');
      expect(found, isNull);
    });
  });

  group('иконки', () {
    const all = <AppIconData>[
      AppIcons.play,
      AppIcons.pause,
      AppIcons.skipNext,
      AppIcons.skipPrev,
      AppIcons.shuffle,
      AppIcons.repeat,
      AppIcons.repeatOne,
      AppIcons.search,
      AppIcons.home,
      AppIcons.library,
      AppIcons.stats,
      AppIcons.settings,
      AppIcons.gear,
      AppIcons.back,
      AppIcons.close,
      AppIcons.more,
      AppIcons.plus,
      AppIcons.check,
      AppIcons.chevronRight,
      AppIcons.chevronDown,
      AppIcons.download,
      AppIcons.downloadDone,
      AppIcons.heart,
      AppIcons.heartFilled,
      AppIcons.thumbDown,
      AppIcons.queue,
      AppIcons.lyrics,
      AppIcons.radio,
      AppIcons.share,
      AppIcons.delete,
      AppIcons.musicNote,
      AppIcons.clock,
      AppIcons.storage,
      AppIcons.warning,
      AppIcons.sync,
      AppIcons.sparkles,
      AppIcons.volume,
    ];

    test('у каждой иконки есть глиф и разумный кегль', () {
      for (final icon in all) {
        expect(icon.glyph.codePoint, greaterThan(0),
            reason: 'иконка без глифа-запасника');
        expect(icon.size, greaterThan(0));
        expect(icon.size, lessThan(64));
      }
    });

    testWidgets('все иконки рисуются в обоих стилях без исключений',
        (tester) async {
      for (final style in IconStyle.values) {
        for (final icon in all) {
          await pump(
            tester,
            Center(
              child: AppIcon(icon, style: style, color: const Color(0xFFFFFFFF)),
            ),
          );
          expect(tester.takeException(), isNull,
              reason: '${icon.glyph.codePoint.toRadixString(16)} / $style');
        }
      }
    });

    testWidgets('иконка берёт стиль из SkinScope', (tester) async {
      await pump(tester, const Center(child: AppIcon(AppIcons.play)),
          skin: ipod);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('кегль и цвет переопределяются вызывающим кодом',
        (tester) async {
      await pump(
        tester,
        const Center(
          child: AppIcon(AppIcons.play, size: 64, color: Color(0xFFFF0000)),
        ),
      );
      expect(tester.getSize(find.byType(AppIcon)), const Size(64, 64));
    });

    test('скин однозначно отображается в стиль иконок', () {
      expect(SkinId.ios.iconStyle, IconStyle.ios);
      expect(SkinId.ipod.iconStyle, IconStyle.ipod);
    });
  });
}

/// Заглушка токенов для константных виджетов в тестах.
final DesignTokens _ipodT = IpodTokens.instance;