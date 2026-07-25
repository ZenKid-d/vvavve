import 'package:flutter/material.dart';

/// Логотип-надпись «vvavve»: первая «v» — жёлтая, вторая «v» — фиолетовая
/// (фирменный акцент), «avve» — обычный цвет текста. Общий виджет, чтобы
/// стиль не разъезжался между шапкой, боковым меню, карточкой шаринга и
/// экраном «О приложении».
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
  static const purple = Color(0xFFB388FF);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? DefaultTextStyle.of(context).style.color,
    );
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: 'v', style: base.copyWith(color: yellow)),
        TextSpan(text: 'v', style: base.copyWith(color: purple)),
        const TextSpan(text: 'avve'),
      ]),
    );
  }
}
