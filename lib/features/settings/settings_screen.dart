import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import 'settings_ios_view.dart';
import 'settings_ipod_view.dart';
import 'settings_widgets.dart';

/// Корень настроек: выбирает представление по скину и держит подэкраны.
///
/// Разделение ровно одно — какая тема. Всё остальное (логика, ключи
/// SharedPreferences, тексты, снекбары) общее и лежит в блоках
/// `settings_widgets.dart`, поэтому переезд в новую тему не должен был
/// ничего менять в поведении.
///
/// Подэкраны — внутреннее состояние, а не маршруты. Причина практическая:
/// роутер в этой фазе переписывает агент оболочки, и восемь новых путей
/// `/settings/*` гарантированно пересеклись бы с его работой. Набор
/// подэкранов при этом остаётся открытым (см. [SettingsSubPage]), так что
/// вынести их в маршруты — однострочное изменение, когда понадобится.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSubPage? _page;

  void _open(SettingsSubPage page) => setState(() => _page = page);

  void _back() => setState(() => _page = null);

  @override
  Widget build(BuildContext context) {
    // Скин берём из провайдера, а не только из SkinScope: экран обязан
    // перерисоваться в момент переключения темы.
    final skin = ref.watch(currentSkinProvider);
    final page = _page;

    final child = page != null && skin.id == SkinId.ios
        ? SettingsIosSubPage(page: page, onBack: _back)
        // В iPod подмен нет: там любой пункт раскрывается на месте, поэтому
        // состояние «открыт подэкран» просто не используется.
        : skin.id == SkinId.ipod
            ? const SettingsIpodView()
            : SettingsIosView(onOpen: _open);

    // Поддерево всегда получает скин, даже если экран поставили вне оболочки
    // (тест, превью, старая навигация). Иначе примитивы тихо взяли бы
    // iOS-токены, и iPod-экран нарисовался бы в чужом виде.
    final inherited = SkinScope.maybeOf(context);
    if (inherited != null && inherited.id == skin.id) return child;
    return SkinScope(skin: skin, child: child);
  }
}