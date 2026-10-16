import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Токены iPod Classic: монохромный графит, почти прямые углы, крупный трекинг.
///
/// Скин держится на двух правилах, и всё остальное выводится из них:
///  * цвет один — статус передаётся ТОНОМ, а не оттенком (см. [_danger] и
///    соседей). Единственное цветное пятно в приложении — логотип на экране
///    загрузки, и оно рисуется отдельно, токенов не касается;
///  * почти нет скруглений — корпус iPod был прямоугольным, и круглые кнопки
///    выбивались бы из образа сильнее, чем помогают.
class IpodTokens implements DesignTokens {
  IpodTokens() : type = DesignTypography.build(
          display: const TypeStep(28, FontWeight.w700, -0.5),
          title: const TypeStep(20, FontWeight.w700, -0.3),
          headline: const TypeStep(15, FontWeight.w700, -0.2),
          body: const TypeStep(14, FontWeight.w400, 0.0),
          caption: const TypeStep(12, FontWeight.w400, 0.2),
          micro: const TypeStep(10, FontWeight.w700, 0.6),
          primary: _textPrimary,
          secondary: _textSecondary,
          tertiary: _textTertiary,
          // Жёстче, чем в iOS: корпус iPod отзывался на нажатие мгновенно,
          // длинные кривые выглядели бы «желеобразно».
          lineHeight: 1.15,
        );

  static final IpodTokens instance = IpodTokens();

  final TextTheme type;

  static const _background = Color(0xFF0E0E10);
  static const _surface = Color(0xFF1A1A1C);
  static const _surfaceAlt = Color(0xFF242426);
  static const _separator = Color(0xFF2A2A2C);
  static const _textPrimary = Color(0xFFFFFFFF);
  // Белый с прозрачностью, а не серый: на монохромном экране серый «съедает»
  // яркость подсветки LCD, а прозрачность сохраняет калибровку яркости.
  static const _textSecondary = Color(0x99FFFFFF); // 60 %
  static const _textTertiary = Color(0x4DFFFFFF); // 30 %
  static const _accent = Color(0xFFFFFFFF);
  static const _accentOn = Color(0xFF0E0E10);

  // Статусы монохромны: «ошибка» — инвертированный светлый блок (самый
  // контрастный тон, его не спутать ни с чем), «предупреждение» — тёмно-серый
  // (гаснет), «успех» — светлый (тот же белый, что акцент). Различить их
  // должен контекст и форма блока, а не оттенок.
  static const _danger = Color(0xFFEFEFEF);
  static const _success = Color(0xFFB4B4B4);
  static const _warning = Color(0xFF8C8C8C);

  /// Строка меню iPod ВЫШЕ строки iOS: у iPod не было сетки, были крупные
  /// пункты, и водить пальцем по разделителю в 32 px неудобно.
  static const double rowHeight = 48;

  /// Сторона обложки крупнее, чем в iOS: на монохромном экране картинка —
  /// единственный источник цвета, её не ущемляем.
  static const double coverSize = 64;

  /// Высота «шапки» меню iPod (заголовок по центру между шевронами).
  static const double menuBarHeight = 44;

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
  double get radiusSm => 0;
  @override
  double get radiusMd => 2;
  @override
  double get radiusLg => 3;
  @override
  double get radiusPill => 3;

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
  Curve get motionCurve => Curves.easeOut;

  @override
  Duration get motionDuration => const Duration(milliseconds: 220);

  /// Текстуру графита рисует painter (см. GraphiteBackground), а не картинка:
  /// это избавляет от зависимости от pubspec-assets и позволяет тонировать
  /// фон под любой размер экрана без растяжения.
  @override
  String? get backgroundTextureAsset => null;
}