import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Постоянный идентификатор установки.
///
/// Нужен для двух вещей: счётчики прослушиваний ведутся отдельно по каждому
/// устройству (иначе при синхронизации они задваиваются), и им же разрешаются
/// ничьи по времени при слиянии. Это не идентификатор пользователя и не
/// аппаратный номер — просто случайная строка, живущая до переустановки.
class DeviceId {
  DeviceId._();

  static const _key = 'device_id';

  static String ensure(SharedPreferences prefs) {
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
    prefs.setString(_key, id);
    return id;
  }
}
