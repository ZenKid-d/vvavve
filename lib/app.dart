import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/accent_provider.dart';
import 'core/theme/app_theme.dart';
import 'design/skin.dart';
import 'design/skin_registry.dart';
import 'l10n/gen/app_localizations.dart';

class RoundedsApp extends ConsumerWidget {
  const RoundedsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(effectiveAccentProvider);
    // Держим связку «вход ↔ синхронизация» живой всё время работы приложения:
    // иначе провайдер ленивый и обмен просто не запустится.
    ref.watch(syncBinderProvider);
    // Скин ставится НАД MaterialApp, а не внутри роутов: тогда его видят и
    // навигатор (переходы берут из него кривую), и примитивы вроде AppIcon,
    // которым не нужен роутер вообще. Смена скина перерисовывает всё дерево
    // приложения, но не пересоздаёт роутер — стек навигации переживает тему.
    final skin = ref.watch(currentSkinProvider);

    return SkinScope(
      skin: skin,
      child: MaterialApp.router(
        title: 'vvavve',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(accent: accent),
        themeAnimationDuration: const Duration(milliseconds: 500),
        routerConfig: ref.watch(appRouterProvider),
        // Приложение изначально писалось с русскими строками прямо в коде —
        // локализация внедряется поэтапно (см. TODO.md #i18n), ru остаётся
        // дефолтом до полного перевода интерфейса.
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}