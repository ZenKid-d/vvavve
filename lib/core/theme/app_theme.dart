import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'theme_settings.dart';

/// Тема приложения для всего, что ещё не переведено на скины.
///
/// Скины (iOS / iPod) рисуют экраны по своим токенам и эту тему почти не видят,
/// но Material-виджеты (Slider, диалоги, поля ввода) берут цвета и шрифт
/// отсюда — поэтому тема остаётся, просто перестаёт быть «настройкой».
///
/// Шрифт — Inter, как в дизайн-системе: два шрифта в одном приложении (Inter в
/// плеере и Poppins в диалогах) выглядели бы как недоделка.
class AppTheme {
  static ThemeData build({required Color accent}) {
    final base = ThemeData.dark(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: AppColors.background,
        onPrimary: Colors.black,
      ),
      textTheme: text,
      extensions: [const AppShapes(kAppRadius)],
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.surface1,
        scrimColor: Colors.black54,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}