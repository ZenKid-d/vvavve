import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import 'ios_home_view.dart';
import 'ipod_home_view.dart';

// Провайдеры главной живут в home_controller.dart, но исторически их брали
// из home_screen.dart (онбординг инвалидирует подборки). Реэкспорт сохраняет
// старые импорты рабочими, чтобы переезд не был ломкой сменой API.
export 'home_controller.dart'
    show dailyPlaylistsProvider, feedProvider, recommendationsProvider;

/// Точка входа на главную.
///
/// Держит ровно одну задачу: выбрать представление по скину. Всё остальное —
/// данные в [home_controller], вид — в `ios_home_view.dart` и
/// `ipod_home_view.dart`. Экраны не наследуют друг друга: это не «одно и то же
/// с двумя настройками», а два разных экрана с общей логикой, и иначе через
/// месяц в каждом накопилось бы по десять `if (ipod)`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(currentSkinProvider);
    return switch (skin.id) {
      SkinId.ios => const IosHomeView(),
      SkinId.ipod => const IpodHomeView(),
    };
  }
}
