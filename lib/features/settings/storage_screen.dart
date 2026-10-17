import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage.dart';
import '../../design/icons/app_icons.dart';
import '../common/skin_tokens.dart';

/// Экран «Управление памятью»: размер загрузок и кэша, очистка.
///
/// Скин берём через [skinOf], а не SkinScope.of: экран может открыться
/// вне оболочки (тест, превью), и падать на этом нельзя — там по умолчанию
/// рисуем iOS-вариант.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  int? _downloadsBytes;
  int? _cacheBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  Future<void> _recompute() async {
    setState(() {
      _downloadsBytes = null;
      _cacheBytes = null;
    });
    final dl = await ref.read(downloadsProvider).downloadsBytes();
    final cache = await Storage.cacheBytes();
    if (mounted) {
      setState(() {
        _downloadsBytes = dl;
        _cacheBytes = cache;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _busy = true);
    await Storage.clearCache();
    await _recompute();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Кэш очищен')));
    }
  }

  Future<void> _removeDownloads() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = skinOf(ctx).tokens;
        return AlertDialog(
          // Диалоги не подкрашиваются скином сами — поверхность берём из
          // токенов, иначе в iPod всплыла бы светлая Material-подложка.
          backgroundColor: t.surface,
          title: Text('Удалить все загрузки?',
              style: t.headline.copyWith(color: t.textPrimary)),
          content: Text(
            'Скачанные треки станут недоступны офлайн. Библиотека и плейлисты '
            'останутся.',
            style: t.body.copyWith(color: t.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Отмена',
                    style: t.caption.copyWith(color: t.textSecondary))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.accentOn,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await ref.read(downloadsProvider).removeAll();
    await _recompute();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Загрузки удалены')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    final downloads = ref.watch(downloadsProvider);
    final count = downloads.downloads.length;
    final total = (_downloadsBytes != null && _cacheBytes != null)
        ? _downloadsBytes! + _cacheBytes!
        : null;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title: Text(
          'Управление памятью',
          style: t.headline.copyWith(color: t.textPrimary),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(t.space16),
        children: [
          _TotalCard(total: total),
          SizedBox(height: t.space16),
          _StorageTile(
            icon: AppIcons.downloadDone,
            title: 'Скачанные треки',
            subtitle: '$count ${_plural(count)}',
            value: _downloadsBytes,
            actionLabel: 'Удалить всё',
            onAction: (_busy || count == 0) ? null : _removeDownloads,
          ),
          // Разделитель — из токенов: hairline Divider Material не совпадает
          // с толщиной/цветом линий скина.
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space12),
            child: Container(height: 1, color: t.separator),
          ),
          _StorageTile(
            icon: AppIcons.download,
            title: 'Кэш (обложки и т.п.)',
            subtitle: 'Пересоздаётся при просмотре',
            value: _cacheBytes,
            actionLabel: 'Очистить',
            onAction: _busy ? null : _clearCache,
          ),
          SizedBox(height: t.space24),
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : _recompute,
              icon: AppIcon(AppIcons.sync, size: 18, color: t.textSecondary),
              label: Text('Пересчитать',
                  style: t.caption.copyWith(color: t.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  static String _plural(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'трек';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'трека';
    }
    return 'треков';
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final int? total;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space16, vertical: t.space24),
      decoration: BoxDecoration(
        // Пятнистый цвет подложки — тот же акцент, что у скина; заливка
        // полупрозрачным акцентом остаётся валидной в монохромном iPod.
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.storage, color: t.accent, size: 30),
          SizedBox(width: t.space16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Занято приложением',
                  style: t.micro.copyWith(color: t.textSecondary)),
              SizedBox(height: t.space4),
              Text(total == null ? '…' : Storage.fmt(total!),
                  style: t.title.copyWith(color: t.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final AppIconData icon;
  final String title;
  final String subtitle;
  final int? value;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Row(
      children: [
        AppIcon(icon, color: t.textSecondary),
        SizedBox(width: t.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: t.body.copyWith(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  Text(value == null ? '…' : Storage.fmt(value!),
                      style: t.body.copyWith(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              SizedBox(height: t.space2),
              Text(subtitle, style: t.micro.copyWith(color: t.textTertiary)),
            ],
          ),
        ),
        SizedBox(width: t.space8),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel,
              style: t.caption.copyWith(color: t.accent)),
        ),
      ],
    );
  }
}
