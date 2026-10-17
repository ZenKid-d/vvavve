import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../domain/models/track.dart';

/// Индикатор состояния скачивания трека для строки списка: кружок-прогресс во
/// время загрузки, отметка «готово» для скачанного и кнопка «скачать» для
/// остального. Сам подписан на [downloadsProvider], поэтому перерисовывается
/// только эта строка, а не весь экран.
class TrackDownloadStatus extends ConsumerWidget {
  const TrackDownloadStatus(this.track, {super.key});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dl = ref.watch(downloadsProvider);
    final t = SkinScope.maybeOf(context)?.tokens;

    if (dl.isDownloading(track.uid)) {
      final p = dl.progressFor(track.uid);
      final c = t?.accent ?? Colors.white;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                  value: p == 0 ? null : p, strokeWidth: 2, color: c),
              // Число процентов внутри кольца, когда прогресс определён.
              if (p > 0)
                Text('${(p * 100).round()}',
                    style: TextStyle(
                        fontSize: 7.5,
                        height: 1,
                        color: c,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    if (dl.isDownloaded(track.uid)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AppIcon(AppIcons.downloadDone,
            size: 20, color: t?.accent ?? Colors.white),
      );
    }
    return IconButton(
      icon: AppIcon(AppIcons.download,
          size: 20, color: t?.textTertiary ?? Colors.white54),
      tooltip: 'Скачать трек',
      onPressed: () => ref.read(downloadsProvider).download(track),
    );
  }
}
