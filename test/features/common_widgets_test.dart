import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/design/icons/app_icons.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:roundds/domain/models/source_type.dart';
import 'package:roundds/domain/models/track.dart';
import 'package:roundds/features/common/album_tile.dart';
import 'package:roundds/features/common/section_tab_bar.dart';
import 'package:roundds/features/common/skin_controls.dart';
import 'package:roundds/features/common/skin_tokens.dart';
import 'package:roundds/features/common/track_row.dart';

/// Общие примитивы экранов в двух темах.
///
/// Проверяем не «красиво», а контракты, которые ломаются тихо: строка обязана
/// показать название и артиста, обязана реагировать на тап, а играющий трек
/// обязана отличаться от обычного в ОБОИХ скинах. Последнее важнее всего:
/// выделение цветом не работает на монохромном iPod, поэтому там нужен другой
/// признак, и без проверки его легко потерять при следующем рефакторинге.
void main() {
  final ios = skinFor(SkinId.ios);
  final ipod = skinFor(SkinId.ipod);

  const track = Track(
    id: 'abc',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    source: SourceType.youtube,
  );
  Future<void> pump(WidgetTester tester, Widget child, {Skin? skin}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SkinScope(
            skin: skin ?? ios,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  group('SkinTrackRow', () {
    for (final skin in [ios, ipod]) {
      final name = skin.id.name;

      testWidgets('$name: показывает название и артиста', (tester) async {
        await pump(
          tester,
          SkinTrackRow(track: track, onTap: () {}),
          skin: skin,
        );
        expect(find.text('Blinding Lights'), findsOneWidget);
        expect(find.text('The Weeknd'), findsOneWidget);
      });

      testWidgets('$name: тап срабатывает', (tester) async {
        var taps = 0;
        await pump(
          tester,
          SkinTrackRow(track: track, onTap: () => taps++),
          skin: skin,
        );
        await tester.tap(find.byType(SkinTrackRow));
        expect(taps, 1);
      });

      testWidgets('$name: активный трек выделен, обычный — нет',
          (tester) async {
        await pump(
          tester,
          Column(
            children: [
              SkinTrackRow(track: track, onTap: () {}, active: true),
              SkinTrackRow(
                key: const Key('plain'),
                track: track,
                onTap: () {},
              ),
            ],
          ),
          skin: skin,
        );
        // iPod помечает играющий трек треугольником ▶ — единственным
        // признаком, который не зависит от палитры.
        final marker = find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.play,
        );
        if (skin.id == SkinId.ipod) {
          expect(marker, findsOneWidget);
        } else {
          expect(marker, findsNothing);
          final activeTitle = tester.widget<Text>(
            find.descendant(
              of: find.byType(SkinTrackRow).first,
              matching: find.text('Blinding Lights'),
            ),
          );
          final plainTitle = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const Key('plain')),
              matching: find.text('Blinding Lights'),
            ),
          );
          expect(activeTitle.style!.color, skin.tokens.accent);
          expect(plainTitle.style!.color, skin.tokens.textPrimary);
        }
      });

      testWidgets('$name: обложка и текст не переполняют строку',
          (tester) async {
        await pump(
          tester,
          SkinTrackRow(
            track: track,
            onTap: () {},
            trailing: const IconDataProbe(),
          ),
          skin: skin,
        );
        expect(tester.takeException(), isNull);
      });
    }

    test('высота строки не меньше обложки в обеих темах', () {
      // Обложка шире строки в обоих скинах — строка обязана расти до неё, иначе
      // картинка вылезет за границы (это ловится только на экране, не в юнит-тесте).
      for (final id in SkinId.values) {
        expect(rowHeightFor(id), greaterThanOrEqualTo(id.coverSize));
      }
    });
  });

  group('SectionTabBar', () {
    testWidgets('iOS: активная вкладка помечена акцентом и подчёркиванием',
        (tester) async {
      await pump(
        tester,
        SectionTabBar(
          labels: const ['Плейлисты', 'Любимое'],
          index: 1,
          onChanged: (_) {},
        ),
      );
      final active = tester.widget<Text>(find.text('Любимое'));
      final inactive = tester.widget<Text>(find.text('Плейлисты'));
      expect(active.style!.color, ios.tokens.accent);
      expect(inactive.style!.color, isNot(ios.tokens.accent));
    });

    testWidgets('тап по вкладке сообщает индекс', (tester) async {
      var picked = -1;
      await pump(
        tester,
        SectionTabBar(
          labels: const ['Плейлисты', 'Любимое', 'Загрузки'],
          index: 0,
          onChanged: (i) => picked = i,
        ),
      );
      await tester.tap(find.text('Загрузки'));
      expect(picked, 2);
    });

    testWidgets('iPod: активный сегмент инвертирован', (tester) async {
      await pump(
        tester,
        SectionTabBar(
          labels: const ['Плейлисты', 'Любимое'],
          index: 0,
          onChanged: (_) {},
          scrollable: false,
        ),
        skin: ipod,
      );
      final active = tester.widget<Text>(find.text('Плейлисты'));
      expect(active.style!.color, ipod.tokens.accentOn);
    });
  });

  group('SkinAlbumTile', () {
    for (final skin in [ios, ipod]) {
      testWidgets('${skin.id.name}: показывает альбом и артиста',
          (tester) async {
        await pump(
          tester,
          SkinAlbumTile(
            title: 'After Hours',
            artist: 'The Weeknd',
            onTap: () {},
          ),
          skin: skin,
        );
        expect(find.text('After Hours'), findsOneWidget);
        expect(find.text('The Weeknd'), findsOneWidget);
      });

      testWidgets('${skin.id.name}: тап открывает альбом', (tester) async {
        var taps = 0;
        await pump(
          tester,
          SkinAlbumTile(
            title: 'After Hours',
            artist: 'The Weeknd',
            onTap: () => taps++,
          ),
          skin: skin,
        );
        await tester.tap(find.byType(SkinAlbumTile));
        expect(taps, 1);
      });
    }
  });

  group('SkinFilterField', () {
    testWidgets('ввод попадает в onChanged, очистка — в onClear',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var cleared = 0;
      var last = '';
      await pump(
        tester,
        SkinFilterField(
          controller: controller,
          hint: 'Фильтр',
          onChanged: (v) => last = v,
          onClear: () => cleared++,
        ),
      );
      await tester.enterText(find.byType(TextField), 'rock');
      expect(last, 'rock');
      await tester.tap(find.byType(AppIcon).last); // крестик очистки
      expect(cleared, 1);
    });
  });

  group('SkinProgressBar и SkinRingProgress', () {
    testWidgets('рисуются в обеих темах и не падают на нуле', (tester) async {
      for (final skin in [ios, ipod]) {
        await pump(
          tester,
          const Column(
            children: [
              SkinProgressBar(value: 0),
              SkinProgressBar(value: 1),
              SkinRingProgress(value: 0),
              SkinRingProgress(value: 0.5),
              SkinRingProgress(value: 1, indeterminate: true),
            ],
          ),
          skin: skin,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}

/// Заглушка-травел в строке: нужна, чтобы проверить, что правый слот не ломает
/// геометрию строки.
class IconDataProbe extends StatelessWidget {
  const IconDataProbe({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(width: 16, height: 16);
}
