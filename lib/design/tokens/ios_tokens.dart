import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Токены iOS-скина: плотный тёмный интерфейс в духе системного оформления.
///
/// Плотность здесь — осознанное решение: iPod-скин просторный, с крупными
/// тапами под палец, а iOS-скин показывает на экране максимум информации,
/// поэтому строка трека 36 px, а обложка 44 px (см. [rowHeight]/[coverSize]).
class IosTokens implements DesignTokens {
  IosTokens() : type = DesignTypography.build(
          display: const TypeStep(34, FontWeight.w700, -0.4),
          title: const TypeStep(22, FontWeight.w700, -0.3),
          headline: const TypeStep(17, FontWeight.w600, -0.2),
          body: const TypeStep(15, FontWeight.w400, -0.1),
          caption: const TypeStep(13, FontWeight.w500, 0.0),
          micro: const TypeStep(11, FontWeight.w500, 0.1),
          primary: _textPrimary,
          secondary: _textSecondary,
          tertiary: _textTertiary,
        );

  /// Экземпляр общий: сборка TextTheme не бесплатна, а токены иммутабельны.
  static final IosTokens instance = IosTokens();

  final TextTheme type;

  // Палитра — системные тёмные цвета iOS (label/secondaryLabel/
  // tertiaryLabel), чтобы светлая и тёмная части приложения читались как одно
  // целое, а не как «ещё один тёмный интерфейс».
  static const _background = Color(0xFF1C1C1E);
  static const _surface = Color(0xFF2C2C2E);
  static const _surfaceAlt = Color(0xFF3A3A3C);
  static const _separator = Color(0xFF38383A);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8E8E93);
  static const _textTertiary = Color(0xFF48484A);
  static const _accent = Color(0xFF0A84FF);
  static const _accentOn = Color(0xFFFFFFFF);
  static const _danger = Color(0xFFFF453A);
  static const _success = Color(0xFF30D158);
  static const _warning = Color(0xFFFF9F0A);

  /// Высота строки списка треков. Меньше 36 — текст перестаёт читаться,
  /// больше — список перестаёт быть плотным.
  static const double rowHeight = 36;

  /// Сторона обложки в строке трека: чуть выше строки, чтобы ряд читался
  /// как «пластинка + подпись», а не как две картинки в ряд.
  static const double coverSize = 44;

  /// Высота нижней панели разделов.
  static const double tabBarHeight = 52;

  @override
  Color get background => _background;
  @override
  Color get surface => _surface;
  @override
  Color get surfaceAlt => _surfaceAlt;
  @override
  Color get separator => _separator;
  @override
  Color get textPrimary => _textPrimary;
  @override
  Color get textSecondary => _textSecondary;
  @override
  Color get textTertiary => _textTertiary;
  @override
  Color get accent => _accent;
  @override
  Color get accentOn => _accentOn;
  @override
  Color get danger => _danger;
  @override
  Color get success => _success;
  @override
  Color get warning => _warning;

  @override
  double get radiusSm => 6;
  @override
  double get radiusMd => 10;
  @override
  double get radiusLg => 16;
  @override
  double get radiusPill => 999;

  @override
  double get space2 => 2;
  @override
  double get space4 => 4;
  @override
  double get space8 => 8;
  @override
  double get space12 => 12;
  @override
  double get space16 => 16;
  @override
  double get space24 => 24;

  @override
  TextStyle get display => type.displayLarge!;
  @override
  TextStyle get title => type.titleLarge!;
  @override
  TextStyle get headline => type.titleMedium!;
  @override
  TextStyle get body => type.bodyMedium!;
  @override
  TextStyle get caption => type.bodySmall!;
  @override
  TextStyle get micro => type.labelSmall!;

  @override
  Curve get motionCurve => Curves.easeOutCubic;

  @override
  Duration get motionDuration => const Duration(milliseconds: 350);

  /// У iOS фона-текстуры нет: ровная заливка плюс материалы — и есть его вид.
  @override
  String? get backgroundTextureAsset => null;
}