import 'package:flutter/material.dart';

/// Логотип-надпись «vvavve»: первые две буквы «vv» — акцентный жёлтый,
/// остальное — обычный цвет текста. Общий виджет, чтобы стиль не разъезжался
/// между шапкой, боковым меню, карточкой шаринга и экраном «О приложении».
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w600,
    this.color,
  });

  final double fontSize;
  final FontWeight fontWeight;

  /// Цвет остальной части («avve»). null — берём цвет из DefaultTextStyle.
  final Color? color;

  static const yellow = Color(0xFFFFD400);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? DefaultTextStyle.of(context).style.color,
    );
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: 'vv', style: base.copyWith(color: yellow)),
        const TextSpan(text: 'avve'),
      ]),
    );
  }
}
