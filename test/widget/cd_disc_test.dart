import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/widgets/cd_disc.dart';

// Диск рисуется целиком на канве — обложек и сетевых запросов здесь нет.
Widget _wrap({
  required bool playing,
  String artist = 'Test Artist',
  String title = 'Test Title',
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: CdDisc(
            isPlaying: playing,
            accent: const Color(0xFFB388FF),
            artist: artist,
            title: title,
            size: 250,
          ),
        ),
      ),
    );

void main() {
  testWidgets('CdDisc строится на паузе и не оставляет висящих анимаций',
      (tester) async {
    await tester.pumpWidget(_wrap(playing: false));
    await tester.pumpAndSettle();
    expect(find.byType(CdDisc), findsOneWidget);
  });

  testWidgets('CdDisc крутится при игре и останавливается на паузе',
      (tester) async {
    await tester.pumpWidget(_wrap(playing: true));
    await tester.pump(const Duration(milliseconds: 500));

    final rotation = find.descendant(
      of: find.byType(CdDisc),
      matching: find.byType(RotationTransition),
    );
    final turns = tester.widget<RotationTransition>(rotation).turns;
    expect(turns.value, greaterThan(0));

    await tester.pumpWidget(_wrap(playing: false));
    await tester.pumpAndSettle(); // не должно зависнуть: контроллер остановлен
    final stopped = turns.value;
    await tester.pump(const Duration(seconds: 1));
    expect(turns.value, stopped);
  });

  testWidgets('CdDisc переживает пустые и очень длинные строки',
      (tester) async {
    await tester.pumpWidget(_wrap(playing: false, artist: '', title: ''));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(
      playing: false,
      artist: 'Очень Длинное Имя Артиста Которое Точно Не Влезает В Дугу',
      title: 'И такое же длинное название трека с эмодзи 🎧 и цифрами 1234567',
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
