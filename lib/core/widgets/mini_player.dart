import 'package:flutter/material.dart';

import '../../features/shell/mini_player_shell.dart';

/// Мини-плеер для экранов вне оболочки (альбом, артист, чарты, плейлист).
///
/// Это тонкая обёртка над [ShellMiniPlayer], а не второй виджет: вид у обоих
/// один и тот же (skin-aware), иначе через месяц на экране альбома и в оболочке
/// играли бы разные мини-плееры. Оболочка зовёт [ShellMiniPlayer] напрямую —
/// так видно, что она строит каркас сама, а не «подставляет» общий виджет.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => const ShellMiniPlayer();
}