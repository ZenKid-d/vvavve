import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/design/ios/ios_skin.dart';
import 'package:roundds/design/ipod/ipod_skin.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:roundds/design/tokens/design_tokens.dart';
import 'package:roundds/design/tokens/ios_tokens.dart';
import 'package:roundds/design/tokens/ipod_tokens.dart';

/// Контракт дизайн-токенов.
///
/// Токены — единственная точка, где живут числа оформления. Если скин может
/// отдать нулевой радиус там, где нужен отступ, или акцент не того цвета,
/// это ловится здесь, а не на «страшном» экране.
void main() {
  final skins = <Skin>[IosSkin(), IpodSkin()];
  final tokens = <SkinId, DesignTokens>{
    SkinId.ios: IosTokens.instance,
    SkinId.ipod: IpodTokens.instance,
  };

  group('палитра', () {
    test('все цвета заданы и не прозрачные', () {
      for (final skin in skins) {
        final t = skin.tokens;
        final colors = <String, Color>{
          'background': t.background,
          'surface': t.surface,
          'surfaceAlt': t.surfaceAlt,
          'separator': t.separator,
          'textPrimary': t.textPrimary,
          'textSecondary': t.textSecondary,
          'textTertiary': t.textTertiary,
          'accent': t.accent,
          'accentOn': t.accentOn,
          'danger': t.danger,
          'success': t.success,
          'warning': t.warning,
        };
        colors.forEach((name, c) {
          expect(c.a, greaterThan(0),
              reason: '${skin.id.name}: $name полностью прозрачен');
          expect(c.a, lessThanOrEqualTo(1), reason: '${skin.id.name}: $name');
        });
        expect(t.background.toARGB32(), isNot(0),
            reason: '${skin.id.name}: фон не должен быть нулевым');
      }
    });

    test('акцент iOS — системный синий', () {
      expect(IosTokens.instance.accent, const Color(0xFF0A84FF));
      expect(IosTokens.instance.accentOn, const Color(0xFFFFFFFF));
    });

    test('iPod монохромен: акцент белый, единственный «цветной» статус — нет', () {
      final t = IpodTokens.instance;
      expect(t.accent, const Color(0xFFFFFFFF));
      // Акцент и текст совпадают: на монохромном экране «синий» был бы
      // единственным пятном, и он забран логотипу на экране загрузки.
      expect(t.accent, t.textPrimary);
      // Текст на белом (инвертированные блоки) обязан быть тёмным, иначе он
      // нечитаем.
      expect(t.accentOn.computeLuminance(), lessThan(t.accent.computeLuminance()));
    });

    test('фон однотонный и не совпадает с поверхностью', () {
      for (final skin in skins) {
        expect(skin.tokens.background, isNot(skin.tokens.surface),
            reason: '${skin.id.name}: экран слипся бы с карточками');
      }
    });
  });

  group('геометрия', () {
    test('радиусы неотрицательные, отступы строго положительные', () {
      for (final skin in skins) {
        final t = skin.tokens;
        final name = skin.id.name;
        // Радиус 0 законен (у iPod почти прямые углы), отрицательный — нет.
        expect(t.radiusSm, greaterThanOrEqualTo(0), reason: '$name radiusSm');
        expect(t.radiusMd, greaterThanOrEqualTo(0), reason: '$name radiusMd');
        expect(t.radiusLg, greaterThanOrEqualTo(0), reason: '$name radiusLg');
        expect(t.radiusPill, greaterThanOrEqualTo(t.radiusLg),
            reason: '$name: «пилюля» должна быть самым круглым радиусом');

        for (final entry in <String, double>{
          'space2': t.space2,
          'space4': t.space4,
          'space8': t.space8,
          'space12': t.space12,
          'space16': t.space16,
          'space24': t.space24,
        }.entries) {
          expect(entry.value, greaterThan(0),
              reason: '$name: ${entry.key} не может быть нулём');
        }
      }
    });

    test('шкала отступов возрастает', () {
      for (final skin in skins) {
        final t = skin.tokens;
        expect(t.space2, lessThan(t.space4));
        expect(t.space4, lessThan(t.space8));
        expect(t.space8, lessThan(t.space12));
        expect(t.space12, lessThan(t.space16));
        expect(t.space16, lessThan(t.space24));
      }
    });

    test('iOS плотный и скруглённый, iPod прямой', () {
      expect(IosTokens.instance.radiusMd, greaterThan(IpodTokens.instance.radiusMd));
      expect(IosTokens.rowHeight, lessThan(IpodTokens.rowHeight));
      expect(IpodTokens.instance.radiusSm, 0);
      expect(IpodTokens.coverSize, greaterThan(IosTokens.coverSize));
    });
  });

  group('типографика', () {
    test('все шесть ролей заданы ненулевым кеглем', () {
      for (final skin in skins) {
        final styles = <String, TextStyle>{
          'display': skin.tokens.display,
          'title': skin.tokens.title,
          'headline': skin.tokens.headline,
          'body': skin.tokens.body,
          'caption': skin.tokens.caption,
          'micro': skin.tokens.micro,
        };
        styles.forEach((name, style) {
          expect(style.fontSize, greaterThan(0),
              reason: '${skin.id.name}: $name без кегля');
          expect(style.fontWeight, isNotNull,
              reason: '${skin.id.name}: $name без начертания');
          expect(style.color, isNotNull,
              reason: '${skin.id.name}: $name без цвета');
          expect(style.fontFamily, anyOf(isNull, isNotEmpty),
              reason: '${skin.id.name}: $name с пустым семейством шрифтов');
        });
      }
    });

    test('кегли убывают от display к micro', () {
      for (final skin in skins) {
        final t = skin.tokens;
        expect(t.display.fontSize!, greaterThan(t.title.fontSize!));
        expect(t.title.fontSize!, greaterThan(t.headline.fontSize!));
        expect(t.headline.fontSize!, greaterThan(t.body.fontSize!));
        expect(t.body.fontSize!, greaterThan(t.caption.fontSize!));
        expect(t.caption.fontSize!, greaterThan(t.micro.fontSize!));
      }
    });

    test('подписи контрастнее основного текста', () {
      // Сравниваем ВОСПРИНИМАЕМУЮ яркость: iOS задаёт подписи плотным серым
      // (#8E8E93, alpha = 1), а iPod — белым с прозрачностью. Без композитинга
      // с фоном белый@60 % и белый@100 % дали бы одинаковую яркость.
      double on(DesignTokens t, Color c) =>
          Color.alphaBlend(c, t.background).computeLuminance();

      for (final skin in skins) {
        final t = skin.tokens;
        expect(on(t, t.caption.color!), lessThan(on(t, t.textPrimary)),
            reason: '${skin.id.name}: подпись не должна быть так же яркой');
        expect(on(t, t.micro.color!), lessThan(on(t, t.caption.color!)),
            reason: '${skin.id.name}: третичная подпись должна быть бледнее');
        expect(on(t, t.textTertiary), lessThan(on(t, t.textSecondary)),
            reason: '${skin.id.name}: третичный цвет должен быть бледнее вторичного');
        // Текст обязан читаться на фоне: полностью «в тон» фона подпись
        // означала бы, что токен выродился.
        expect(on(t, t.textPrimary) - on(t, t.background), greaterThan(0.4),
            reason: '${skin.id.name}: основной текст сливается с фоном');
      }
    });
  });

  group('анимация', () {
    test('кривая и длительность заданы у обоих скинов', () {
      for (final skin in skins) {
        expect(skin.tokens.motionCurve, isNotNull);
        expect(skin.tokens.motionDuration.inMicroseconds, greaterThan(0));
        // Слишком быстрый переход читается как «мигание», слишком долгий —
        // как лаг. Верхняя граница здесь скорее страховка от опечаток.
        expect(skin.tokens.motionDuration.inMilliseconds, lessThan(1000));
      }
      expect(IosTokens.instance.motionDuration.inMilliseconds,
          greaterThan(IpodTokens.instance.motionDuration.inMilliseconds),
          reason: 'iPod отзывался на нажатие мгновенно, iOS — мягче');
    });
  });

  group('текстура фона', () {
    test('скины рисуют фон кодом, а не картинкой', () {
      // Пока pubspec не объявляет assets, текстура графита рисуется painter'ом:
      // backgroundTextureAsset обязан быть null, иначе SkinCanvas попытается
      // загрузить несуществующий asset.
      for (final skin in skins) {
        expect(skin.tokens.backgroundTextureAsset, isNull,
            reason: '${skin.id.name}: asset-текстуры пока нет');
      }
    });
  });

  group('реестр скинов', () {
    test('skinFor отдаёт реализацию своего id', () {
      expect(skinFor(SkinId.ios), isA<IosSkin>());
      expect(skinFor(SkinId.ipod), isA<IpodSkin>());
      for (final id in SkinId.values) {
        expect(skinFor(id).id, id);
      }
    });

    test('скины — синглтоны: токены не пересобираются на каждый rebuild', () {
      expect(identical(skinFor(SkinId.ios), skinFor(SkinId.ios)), isTrue);
      expect(identical(skinFor(SkinId.ipod), skinFor(SkinId.ipod)), isTrue);
    });

    test('скин отдаёт те же токены, что и реестр', () {
      expect(IosSkin().tokens, same(IosTokens.instance));
      expect(IpodSkin().tokens, same(IpodTokens.instance));
      for (final id in SkinId.values) {
        expect(skinFor(id).tokens, same(tokens[id]));
      }
    });
  });

  group('SkinSection', () {
    test('разделов ровно столько же, сколько элементов в enum', () {
      expect(SkinSection.values, isNotEmpty);
      expect(SkinSection.values.first, SkinSection.home);
      // Индекс раздела — это `sectionIndex` оболочки, поэтому он обязан быть
      // валидным индексом в SkinSection.values.
      for (final s in SkinSection.values) {
        expect(s.index, inInclusiveRange(0, SkinSection.values.length - 1));
        expect(s.title.trim(), isNotEmpty);
      }
    });
  });
}