import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ios/ios_skin.dart';
import 'ipod/ipod_skin.dart';
import 'skin.dart';

/// Экземпляры скинов — синглтоны.
///
/// Токены иммутабельны, а в IosTokens/IpodTokens лежит собранный TextTheme;
/// создавать скин заново на каждый rebuild оболочки значило бы пересобирать
/// типографику впустую.
final IosSkin _ios = IosSkin();
final IpodSkin _ipod = IpodSkin();

/// Скин по идентификатору. Единственное место, где [SkinId] превращается в
/// конкретную реализацию — остальной код знает только интерфейс [Skin].
Skin skinFor(SkinId id) => switch (id) {
      SkinId.ios => _ios,
      SkinId.ipod => _ipod,
    };

/// Текущий скин из выбранного пользователем.
///
/// Отдельный провайдер, а не чтение skinProvider на месте: оболочка перестраивается
/// при смене скина целиком, и один watch вместо двух `ref.watch` не даёт
/// пересобрать дерево промежуточных экранов.
final currentSkinProvider = Provider<Skin>(
  (ref) => skinFor(ref.watch(skinProvider)),
);