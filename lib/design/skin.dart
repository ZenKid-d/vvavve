import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import 'tokens/design_tokens.dart';

/// Идентификатор скина. Хранится в SharedPreferences по [SkinId.name], поэтому
/// новые варианты добавляем ТОЛЬКО в конец и не переименовываем старые.
enum SkinId { ios, ipod }

/// Разделы, которые переключает оболочка ([Skin.buildShell]).
///
/// Настройки намеренно не входят в перечисление: в iOS это иконка в панели, а
/// в iPod — пункт в меню, и держать их «одним разделом» значило бы заставить
/// скин рисовать то, что ему чужое. Поэтому настройки приходят отдельным
/// колбэком [Skin.buildShell]onSettings.
enum SkinSection { home, search, library, stats }

extension SkinSectionX on SkinSection {
  String get title => switch (this) {
        SkinSection.home => 'Главная',
        SkinSection.search => 'Поиск',
        SkinSection.library => 'Медиатека',
        SkinSection.stats => 'Статистика',
      };
}

/// Скин = «как выглядит и ведёт себя экран».
///
/// Экраны НЕ наследуют этот класс: скин собирает их сам (см. buildHome и
/// соседей). Так один и тот же экран может жить в двух оболочках, а данные
/// и логика остаются в контроллерах.
abstract class Skin {
  SkinId get id;

  /// Токены скина. Экраны берут цвета/радиусы/шрифты только отсюда.
  DesignTokens get tokens;

  /// Каркас навигации: iOS рисует нижнюю панель, iPod — меню. [body] — уже
  /// собранный экран раздела.
  Widget buildShell(
    BuildContext context,
    Widget body, {
    required int sectionIndex,
    required ValueChanged<int> onSection,
    required VoidCallback onSettings,
  });

  Widget buildHome(BuildContext context);
  Widget buildSearch(BuildContext context);
  Widget buildLibrary(BuildContext context);
  Widget buildStats(BuildContext context);
  Widget buildSettings(BuildContext context);
  Widget buildPlayer(BuildContext context);

  /// Экран раздела по индексу — мост между оболочкой и экранами.
  Widget buildSection(BuildContext context, SkinSection section) =>
      switch (section) {
        SkinSection.home => buildHome(context),
        SkinSection.search => buildSearch(context),
        SkinSection.library => buildLibrary(context),
        SkinSection.stats => buildStats(context),
      };
}

/// Доступ к скину из контекста: `SkinScope.of(context)`.
///
/// Именно InheritedWidget, а не только Riverpod: виджеты-примитивы (строка
/// списка, заголовок) не должны знать про провайдеры, иначе ими нельзя
/// пользоваться в обычном тесте и в превью.
class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final Skin skin;

  static Skin of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkinScope>();
    assert(scope != null, 'SkinScope не найден: экран должен быть под скином');
    return scope!.skin;
  }

  /// Мягкий вариант для виджетов, которые умеют работать и без скина
  /// (тесты, превью) — подставляют нейтральные значения.
  static Skin? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin;

  @override
  bool updateShouldNotify(SkinScope oldWidget) => oldWidget.skin.id != skin.id;
}

/// Выбранный скин. По умолчанию iOS: релиз выходит iOS-темой первой, и новый
/// пользователь не должен попадать в недоделанный iPod.
final skinProvider = NotifierProvider<SkinController, SkinId>(SkinController.new);

class SkinController extends Notifier<SkinId> {
  /// Ключ в SharedPreferences. С префиксом `ap_`, как остальные настройки.
  static const String storageKey = 'ap_skin';

  @override
  SkinId build() {
    final saved = ref.read(prefsProvider).getString(storageKey);
    for (final id in SkinId.values) {
      if (id.name == saved) return id;
    }
    return SkinId.values.first;
  }

  /// Переключение скина. Состояние обновляем сразу (экран должен перерисоваться
  /// без мигания), а запись отдаём в SharedPreferences — она синхронная по API,
  /// но внутри асинхронна по факту, и ошибку писать некуда.
  Future<void> select(SkinId id) async {
    if (state == id) return;
    state = id;
    await ref.read(prefsProvider).setString(storageKey, id.name);
  }
}