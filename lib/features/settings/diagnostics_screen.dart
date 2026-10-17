import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics.dart';
import '../../core/providers.dart';
import '../../design/icons/app_icons.dart';
import '../../design/tokens/design_tokens.dart';
import '../../design/widgets/blocks.dart';
import '../common/skin_tokens.dart';

/// Внутренний журнал диагностики: последние события источников (поиск, резолв
/// потока, троттлинг, обновление ключей). Помогает понять в поле, почему трек
/// не заиграл или поиск пуст — без внешней телеметрии. Данные только в памяти,
/// сбрасываются при перезапуске.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diag = ref.watch(diagnosticsProvider);
    // Синглтон — не Riverpod-провайдер; на его изменения подписываемся напрямую.
    return ListenableBuilder(
      listenable: diag,
      builder: (context, _) => _build(context, diag),
    );
  }

  Widget _build(BuildContext context, Diagnostics diag) {
    final t = skinOf(context).tokens;
    // Новые сверху.
    final entries = diag.entries.reversed.toList();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title:
            Text('Диагностика', style: t.headline.copyWith(color: t.textPrimary)),
        actions: [
          // «Копировать» у AppIcons нет — рисуем share-глиф (стрелка вверх из
          // коробки): жест тот же, а Material-иконка в скин-слое запрещена.
          IconButton(
            tooltip: 'Скопировать журнал',
            icon: AppIcon(AppIcons.share, size: 20, color: t.textSecondary),
            onPressed: entries.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                        ClipboardData(text: diag.export()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Журнал скопирован')),
                      );
                    }
                  },
          ),
          IconButton(
            tooltip: 'Очистить',
            icon: AppIcon(AppIcons.delete, size: 20, color: t.textSecondary),
            onPressed: entries.isEmpty ? null : diag.clear,
          ),
        ],
      ),
      body: entries.isEmpty
          ? EmptyState(
              tokens: t,
              icon: AppIcons.systemUpdate,
              title: 'Пока пусто',
              subtitle: 'Здесь появятся события источников — ошибки поиска, '
                  'недоступные потоки, троттлинг YouTube и т.п. Если что-то не '
                  'играет, зайди сюда и скопируй журнал.')
          : ListView.separated(
              padding: EdgeInsets.symmetric(vertical: t.space8),
              itemCount: entries.length,
              separatorBuilder: (_, __) => Container(
                height: 1,
                color: t.separator,
              ),
              itemBuilder: (_, i) => _EntryTile(entries[i]),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final DiagEntry entry;

  /// Уровень важности передаётся цветом из токенов, а не AppColors: в
  /// монохромном iPod все три уровня стали бы тонами серого — и это осознанно.
  Color _color(DesignTokens t) => switch (entry.level) {
        DiagLevel.info => t.textTertiary,
        DiagLevel.warn => t.warning,
        DiagLevel.error => t.danger,
      };

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space16, vertical: t.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Точка уровня — нарисованный кружок, а не Icon(Icons.circle):
          // заполненный глиф радиусом 10 не тянет иконку.
          Padding(
            padding: EdgeInsets.only(top: t.space4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _color(t),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: t.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.message,
                    style: t.body.copyWith(color: t.textPrimary)),
                SizedBox(height: t.space2),
                Text('${entry.clock} · ${entry.tag}',
                    style: t.micro.copyWith(color: t.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
