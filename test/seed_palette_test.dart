import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/theme/seed_palette.dart';

void main() {
  test('хеш детерминирован для одной и той же строки', () {
    expect(stableSeedHash('Aphex Twin — Xtal'),
        stableSeedHash('Aphex Twin — Xtal'));
    expect(seedHue('Aphex Twin — Xtal'), seedHue('Aphex Twin — Xtal'));
  });

  test('известные значения — хеш не должен «поехать» между версиями', () {
    // Если этот тест упал, у всех пользователей поменялись оттенки дисков.
    expect(stableSeedHash(''), 0x811C9DC5);
    expect(stableSeedHash('a'), 0x2B24D044);
    expect(stableSeedHash('Кино'), 0x4061159C);
  });

  test('разные треки дают разные оттенки', () {
    final hues = {
      seedHue('Aphex Twin — Xtal'),
      seedHue('Aphex Twin — Ageispolis'),
      seedHue('Boards of Canada — Roygbiv'),
      seedHue('Кино — Группа крови'),
    };
    expect(hues.length, 4);
  });

  test('кириллица не схлопывается в один хеш', () {
    expect(stableSeedHash('Кино'), isNot(stableSeedHash('Лино')));
    expect(stableSeedHash('абв'), isNot(stableSeedHash('абг')));
  });

  test('оттенок всегда в диапазоне 0..360', () {
    for (final s in ['', 'x', 'Очень длинное название трека 12345', '🎧']) {
      final h = seedHue(s);
      expect(h, greaterThanOrEqualTo(0));
      expect(h, lessThan(360));
    }
  });
}
