import 'package:flutter/widgets.dart';

import '../../design/skin.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/tokens/ios_tokens.dart';
import '../../design/tokens/ipod_tokens.dart';

/// Скин и его токены одним обращением к контексту.
///
/// Экран почти всегда решает сразу две задачи: какие числа брать ([tokens]) и
/// «как я выгляжу» ([id] — строка это iOS-плотная или iPod-крупная). Два
/// отдельных обращения к InheritedWidget дали бы две подписки там, где хватает
/// одной, поэтому отдаём пару. Разбирается и полями
/// (`final (:id, :tokens) = skinOf(context)`), и точечно
/// (`skinOf(context).tokens`) — кому как удобнее.
class SkinHandle {
  const SkinHandle(this.id, this.tokens);

  final SkinId id;
  final DesignTokens tokens;
}

/// Какой скин действует в этом месте дерева.
///
/// Мягкий вариант вместо [SkinScope.of]: экран может оказаться вне скина — в
/// юнит-тесте, в превью или в старой оболочке, которую ещё не перевели на
/// [Skin]. Падать на этом месте нельзя (потеряется весь экран), а iOS-вариант
/// даёт читаемый интерфейс вместо пустоты: он нейтральный, без фирменного
/// цвета, поэтому в него не «вписывается» ни одна из тем.
SkinHandle skinOf(BuildContext context) {
  final skin = SkinScope.maybeOf(context);
  return skin == null
      ? SkinHandle(SkinId.ios, IosTokens.instance)
      : SkinHandle(skin.id, skin.tokens);
}

/// Метрики строк и обложек живут не в [DesignTokens], а в конкретных токенах
/// скина: у них разная плотность, и прятать эти числа в базовый контракт —
/// значит размазать «почему iOS плотнее» по половине экрана.
extension SkinIdMetrics on SkinId {
  bool get isIpod => this == SkinId.ipod;
  bool get isIos => !isIpod;

  /// Высота строки списка.
  double get rowHeight => isIpod ? IpodTokens.rowHeight : IosTokens.rowHeight;

  /// Сторона обложки в строке.
  double get coverSize => isIpod ? IpodTokens.coverSize : IosTokens.coverSize;
}

/// Высота строки = максимум из «высоты текстовой строки» и «стороны обложки».
///
/// Отдельный токен [SkinIdMetrics.rowHeight] меньше обложки, и складывать их
/// вручную в каждом экране — верный способ получить переполнение в одной из
/// тем: строка должна быть не ниже картинки, иначе обложка вылезет за неё.
double rowHeightFor(SkinId id) {
  final byCover = id.coverSize;
  return byCover > id.rowHeight ? byCover : id.rowHeight;
}
