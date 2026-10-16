import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайн-токены скина.
///
/// Это НЕ описание «темы Material», а полный контракт оформления: экран
/// спрашивает у токенов цвет, радиус, отступ и стиль текста и не знает, iOS
/// перед ним или iPod. Поэтому контракт закрытый — всё, что влияет на вид,
/// обязано жить здесь, иначе экран снова привяжется к конкретному скину.
abstract class DesignTokens {
  /// Фон экрана.
  Color get background;

  /// Карточки, панели, плавающие блоки.
  Color get surface;

  /// Вложенные поверхности: поля ввода, ячейки внутри карточки.
  Color get surfaceAlt;

  /// Разделители и обводки.
  Color get separator;

  /// Основной текст.
  Color get textPrimary;

  /// Подписи, второстепенные подписи строк.
  Color get textSecondary;

  /// Третичные подписи, плейсхолдеры.
  Color get textTertiary;

  /// Акцент скина. В монохромном iPod это тот же белый, а в iOS — синий.
  Color get accent;

  /// Текст/иконка ПОВЕРХ акцента (инвертированные блоки на iPod).
  Color get accentOn;

  Color get danger;
  Color get success;
  Color get warning;

  // Геометрия. Радиус 0 — законное значение (iPod почти прямой), поэтому
  // проверять контракт надо на «неотрицательность», а не на «положительность».
  double get radiusSm;
  double get radiusMd;
  double get radiusLg;
  double get radiusPill;

  // Отступы — строго положительные: нулевой отступ означал бы слипшиеся
  // элементы, и это почти всегда ошибка в скине, а не замысел.
  double get space2;
  double get space4;
  double get space8;
  double get space12;
  double get space16;
  double get space24;

  // Типографика.
  TextStyle get display;
  TextStyle get title;
  TextStyle get headline;
  TextStyle get body;
  TextStyle get caption;
  TextStyle get micro;

  /// Кривая всех переходов скина. Экраны не должны хардкодить Curves.* —
  /// иначе iOS-скин начнёт анимироваться как iPod и наоборот.
  Curve get motionCurve;
  Duration get motionDuration;

  /// Картинка-текстура фона. null — фон рисует сам скин (см. GraphiteBackground),
  /// потому что не каждому скину текстура вообще нужна.
  String? get backgroundTextureAsset;
}

/// Один шаг типографической шкалы: кегль, начертание, трекинг.
class TypeStep {
  const TypeStep(this.size, this.weight, this.tracking);

  final double size;
  final FontWeight weight;

  /// letterSpacing в логических пикселях. Бывает отрицательным: крупные
  /// кегли Inter «разъезжаются», и оба скина это компенсируют.
  final double tracking;
}

/// Сборщик TextTheme из Inter.
///
/// Вынесен отдельно от токенов, потому что обе темы используют один и тот же
/// шрифт и отличаются только кеглями/начертаниями/трекингом. Держать это в
/// двух местах — значит через месяц получить iOS с Poppins и iPod с Inter.
abstract final class DesignTypography {
  /// Подложка из Inter. google_fonts подгружает начертание АСИНХРОННО и при
  /// неудаче (первый запуск офлайн, юнит-тесты, CI без сети) роняет
  /// необработанную ошибку в зону — из-за чего падает даже тот код, который
  /// шрифт лишь читает. Глушим её здесь: Flutter сам откатится на системный
  /// шрифт через fontFamilyFallback, а падать из-за этого нельзя.
  static TextTheme _interBase() {
    TextTheme? out;
    runZonedGuarded(
      () => out = GoogleFonts.interTextTheme(),
      (Object _, StackTrace __) {},
    );
    return out ?? const TextTheme();
  }

  /// Собирает готовый TextTheme: шесть семантических ролей, заданных скином.
  static TextTheme build({
    required TypeStep display,
    required TypeStep title,
    required TypeStep headline,
    required TypeStep body,
    required TypeStep caption,
    required TypeStep micro,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    double lineHeight = 1.25,
  }) {
    final base = _interBase();

    TextStyle at(TextStyle? proto, TypeStep step, Color color) =>
        (proto ?? const TextStyle()).copyWith(
          fontSize: step.size,
          fontWeight: step.weight,
          letterSpacing: step.tracking,
          height: lineHeight,
          color: color,
        );

    return base.copyWith(
      displayLarge: at(base.displayLarge, display, primary),
      titleLarge: at(base.titleLarge, title, primary),
      titleMedium: at(base.titleMedium, headline, primary),
      bodyMedium: at(base.bodyMedium, body, primary),
      bodySmall: at(base.bodySmall, caption, secondary),
      labelSmall: at(base.labelSmall, micro, tertiary),
    );
  }
}