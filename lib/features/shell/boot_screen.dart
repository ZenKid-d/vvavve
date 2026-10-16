import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/wordmark.dart';
import '../../design/ipod/ipod_widgets.dart';
import '../../design/skin.dart';
import '../../design/tokens/ipod_tokens.dart';

/// Показывали ли мы уже экран загрузки iPod.
///
/// Флаг нужен, потому что сам экран — не украшение, а задержка запуска: держать
/// её на каждом холодном старте значит каждый раз отнимать у пользователя
/// полторы секунды ради ностальгии. Один раз на смену скина — достаточно, чтобы
/// образ закрепился, и не навязчив.
class BootSeenController extends Notifier<bool> {
  /// Ключ в SharedPreferences. С префиксом `ap_`, как остальные настройки.
  static const String storageKey = 'ap_skin_boot';

  @override
  bool build() => ref.read(prefsProvider).getBool(storageKey) ?? false;

  void markSeen() {
    state = true;
    ref.read(prefsProvider).setBool(storageKey, true);
  }
}

final bootSeenProvider =
    NotifierProvider<BootSeenController, bool>(BootSeenController.new);

/// Экран загрузки iPod-темы: логотип, полоса прогресса, монохромная подпись.
///
/// Существует только ради iPod-скина и открывается только им: у корпуса был
/// чёрный экран с логотипом, который загорался при включении. Логотип — единственное
/// цветное пятно монохромной темы, и оно тут единственное: [Wordmark] рисует
/// жёлто-фиолетовую «vvavve» сама, минуя токены.
///
/// [onFinished] вызывается один раз, когда полоса дошла до конца. Если он null,
/// экран просто показывает анимацию и никуда не ведёт — так его удобно
/// показывать в тесте или превью.
class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    this.onFinished,
    this.minimumDuration = const Duration(milliseconds: 1400),
  });

  final VoidCallback? onFinished;

  /// Нижняя граница показа. Экран существует ради образа, и мигающий логотип
  /// хуже, чем лёгкая задержка — но и задерживать запуск дольше нельзя.
  final Duration minimumDuration;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.minimumDuration,
  );

  bool _reported = false;

  @override
  void initState() {
    super.initState();
    // Полоса идёт до конца параллельно с таймером минимальной длительности —
    // «загрузка» не должна выглядеть как мгновенная вспышка даже при коротком
      // старте.
    _c.forward();
    Future<void>.delayed(widget.minimumDuration, () {
      if (mounted) _finish();
    });
  }

  void _finish() {
    if (_reported) return;
    _reported = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SkinScope.maybeOf(context)?.tokens ?? IpodTokens.instance;
    return Scaffold(
      backgroundColor: tokens.background,
      body: GraphiteBackground(
        base: tokens.background,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кегль логотипа берём из типографики скина: у iPod это
                // display (28), а не «просто 28 на глаз».
                Wordmark(
                  fontSize: tokens.display.fontSize ?? 28,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
                SizedBox(height: tokens.space24),
                SizedBox(
                  width: 220,
                  // Полоса и подпись — одним AnimatedBuilder: иначе надпись
                  // «Готово» осталась бы прежней, пока полоса уже доехала.
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _c.value,
                          minHeight: tokens.space4,
                          color: tokens.accent,
                          backgroundColor: tokens.separator,
                          // На iPod радиус токена нулевой — полоса выходит
                          // прямой, как шкала на LCD, а не как капсула из iOS.
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSm),
                        ),
                        SizedBox(height: tokens.space12),
                        Text(
                          _c.value >= 1 ? 'Готово' : 'Загрузка',
                          style:
                              tokens.micro.copyWith(color: tokens.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}