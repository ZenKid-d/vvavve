import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roundds/core/providers.dart';
import 'package:roundds/core/theme/accent_provider.dart';
import 'package:roundds/core/theme/theme_settings.dart';
import 'package:roundds/core/widgets/sync_status_text.dart';
import 'package:roundds/sync/sync_service.dart' show SyncState;

Future<Widget> _wrap(SyncState state, {AnimLevel anim = AnimLevel.max}) async {
  SharedPreferences.setMockInitialValues({'ap_anim': anim.index});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      // Настоящий акцент считается из обложки играющего трека и тянет за собой
      // весь плеер. Здесь проверяется поведение анимации, а не подбор цвета.
      effectiveAccentProvider.overrideWithValue(const Color(0xFFB388FF)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SyncStatusText(text: 'Синхронизировано', state: state),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('во время обмена по строке бежит перелив', (tester) async {
    await tester.pumpWidget(await _wrap(SyncState.syncing));
    await tester.pump();

    expect(find.text('Синхронизировано'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    // Анимация живая: кадры продолжают запрашиваться.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('при «минимуме анимаций» перелива нет', (tester) async {
    await tester.pumpWidget(await _wrap(SyncState.syncing, anim: AnimLevel.min));
    await tester.pumpAndSettle();

    // Настройка «минимум анимаций» — это про уважение к пользователю, а не
    // про красоту: бегущая волна не должна её игнорировать.
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Синхронизировано'), findsOneWidget);
  });

  testWidgets('ошибка показывается без перелива', (tester) async {
    await tester.pumpWidget(await _wrap(SyncState.error));
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('после обмена анимация останавливается и не виснет',
      (tester) async {
    await tester.pumpWidget(await _wrap(SyncState.syncing));
    await tester.pump(const Duration(milliseconds: 200));

    // Обмен завершился: одна волна «готово» и остановка.
    await tester.pumpWidget(await _wrap(SyncState.idle));
    await tester.pumpAndSettle();

    expect(find.text('Синхронизировано'), findsOneWidget);
  });
}
