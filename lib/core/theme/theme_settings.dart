import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

enum AccentMode { dynamic, preset, custom }

enum AnimLevel { max, moderate, min }

/// Радиус скруглений для Material-виджетов, которые остались вне скинов
/// (AlertDialog, Card, старые экраны).
///
/// Раньше это была настройка «Скругления углов» с тремя вариантами. С появлением
/// двух скинов ручка стала вредной: у iPod радиусы почти нулевые, у iOS — крупные,
/// и общий радиус для обоих означал либо «скруглить корпус iPod», либо
/// «посадить iOS на квадратные кнопки». Скин задаёт форму сам (см. DesignTokens),
/// а это значение — только для того, что скина не касается.
const double kAppRadius = 12;

/// Тёмные фоны-пресеты.
class BgPreset {
  final String name;
  final Color background;
  final Color surface1;
  final Color surface2;
  const BgPreset(this.name, this.background, this.surface1, this.surface2);
}

const kBgPresets = <BgPreset>[
  BgPreset('AMOLED', Color(0xFF000000), Color(0xFF0C0C0C), Color(0xFF141414)),
  BgPreset('Тёмно-серый', Color(0xFF121212), Color(0xFF1C1C1C),
      Color(0xFF262626)),
];

/// Готовые акцентные палитры.
const kAccentPresets = <Color>[
  Color(0xFF1DB954), // зелёный
  Color(0xFF4FC3F7), // циан
  Color(0xFFE040FB), // маджента
  Color(0xFFFFC107), // золото
  Color(0xFFB388FF), // фиолетовый
  Color(0xFFFF6E6E), // коралл
];

/// Расширение темы — несёт радиус скруглений для виджетов вне скинов.
class AppShapes extends ThemeExtension<AppShapes> {
  final double radius;
  const AppShapes(this.radius);

  @override
  AppShapes copyWith({double? radius}) => AppShapes(radius ?? this.radius);

  @override
  AppShapes lerp(ThemeExtension<AppShapes>? other, double t) {
    if (other is! AppShapes) return this;
    return AppShapes(radius * (1 - t) + other.radius * t);
  }
}

/// Настройки внешнего вида, хранятся в SharedPreferences.
class ThemeSettingsController extends ChangeNotifier {
  ThemeSettingsController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  int bgIndex = 0;
  AccentMode accentMode = AccentMode.dynamic;
  int presetIndex = 4;
  int customColor = 0xFFB388FF;
  AnimLevel animLevel = AnimLevel.max;

  BgPreset get bg => kBgPresets[bgIndex.clamp(0, kBgPresets.length - 1)];
  Color get presetColor =>
      kAccentPresets[presetIndex.clamp(0, kAccentPresets.length - 1)];

  bool get spin => animLevel != AnimLevel.min;
  bool get richMotion => animLevel == AnimLevel.max;

  /// Ключи настроек, которые ушли вместе с редизайном (винил/CD, скругления,
  /// системный шрифт). Чистим при первом запуске: в prefs они больше не читаются,
  /// а мусорные значения только занимают место и путают при отладке.
  static const List<String> _obsoleteKeys = [
    'ap_player', // вид плеера: винил / обложка / CD
    'ap_corners', // скругления углов
    'ap_sysfont', // переключатель шрифта Poppins / системный
  ];

  void _load() {
    bgIndex = _prefs.getInt('ap_bg') ?? 0;
    accentMode = AccentMode.values[_prefs.getInt('ap_accentMode') ?? 0];
    presetIndex = _prefs.getInt('ap_preset') ?? 4;
    customColor = _prefs.getInt('ap_custom') ?? 0xFFB388FF;
    animLevel = AnimLevel.values[_prefs.getInt('ap_anim') ?? 0];
    for (final key in _obsoleteKeys) {
      // remove возвращает Future<bool>: ждать нечего, ошибка записи в prefs
      // не должна ронять запуск приложения.
      _prefs.remove(key);
    }
    AppColors.applyBackground(bg.background, bg.surface1, bg.surface2);
    notifyListeners();
  }

  void setBackground(int i) {
    bgIndex = i;
    AppColors.applyBackground(bg.background, bg.surface1, bg.surface2);
    _prefs.setInt('ap_bg', i);
    notifyListeners();
  }

  void setAccentMode(AccentMode m) {
    accentMode = m;
    _prefs.setInt('ap_accentMode', m.index);
    notifyListeners();
  }

  void setPreset(int i) {
    presetIndex = i;
    _prefs.setInt('ap_preset', i);
    notifyListeners();
  }

  void setCustomColor(int argb) {
    customColor = argb;
    _prefs.setInt('ap_custom', argb);
    notifyListeners();
  }

  void setAnimLevel(AnimLevel l) {
    animLevel = l;
    _prefs.setInt('ap_anim', l.index);
    notifyListeners();
  }
}