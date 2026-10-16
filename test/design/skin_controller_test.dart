import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/design/skin.dart';
import 'package:roundds/design/skin_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Выбор скина переживает перезапуск: иначе пользователь каждый раз
/// возвращался бы в iOS и правка в настройках была бы бессмысленной.
void main() {
  Future<ProviderContainer> container(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
  }

  test('по умолчанию — iOS: релиз выходит iOS-темой первой', () async {
    final c = await container({});
    addTearDown(c.dispose);
    expect(c.read(skinProvider), SkinId.ios);
    // Ключ в prefs не задан, пока пользователь ничего не выбрал: записи
    // «втихую» при первом чтении быть не должно.
    expect(c.read(skinProvider), SkinId.values.first);
  });

  test('выбранный скин читается из prefs', () async {
    final c = await container({SkinController.storageKey: 'ipod'});
    addTearDown(c.dispose);
    expect(c.read(skinProvider), SkinId.ipod);
  });

  test('select сохраняет значение и обновляет состояние', () async {
    final c = await container({});
    addTearDown(c.dispose);
    expect(c.read(skinProvider), SkinId.ios);

    await c.read(skinProvider.notifier).select(SkinId.ipod);
    expect(c.read(skinProvider), SkinId.ipod);
    expect(
      c.read(prefsProvider).getString(SkinController.storageKey),
      'ipod',
    );
  });

  test('мусор в prefs не ломает запуск — падаем на скин по умолчанию', () async {
    final c = await container({SkinController.storageKey: 'winamp'});
    addTearDown(c.dispose);
    expect(c.read(skinProvider), SkinId.ios);
  });

  test('currentSkinProvider отдаёт реализацию выбранного скина', () async {
    final c = await container({SkinController.storageKey: 'ipod'});
    addTearDown(c.dispose);
    expect(c.read(currentSkinProvider).id, SkinId.ipod);
  });
}