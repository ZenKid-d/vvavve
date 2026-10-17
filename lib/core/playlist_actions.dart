import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/icons/app_icons.dart';
import '../design/skin.dart';
import '../design/skin_registry.dart';
import '../domain/models/track.dart';
import 'providers.dart';

/// Общий bottom-sheet «Добавить в плейлист». Раньше та же логика была
/// продублирована в [showTrackMenu] (lib/core/track_menu.dart) и на экране
/// плеера (lib/features/player/now_playing_screen.dart) — с небольшими
/// расхождениями (один умел создавать плейлист, другой показывал пустое
/// состояние). Здесь — единая полная версия.
///
/// Показывает список существующих плейлистов + пункт «Новый плейлист»,
/// после выбора показывает снек и закрывает шторку.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final lib = ref.read(libraryProvider);
  // Модальное окно живёт вне дерева экрана — скин берём до открытия.
  final t = SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ios).tokens;
  await showModalBottomSheet(
    context: context,
    backgroundColor: t.surface,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Добавить в плейлист',
                style: TextStyle(
                    fontSize: t.body.fontSize,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
          ),
          ListTile(
            leading: AppIcon(AppIcons.plus, size: 20, color: t.accent),
            title: const Text('Новый плейлист'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final name = await _askPlaylistName(context);
              if (name == null || name.isEmpty) return;
              final pl = await lib.createPlaylist(name);
              await lib.addToPlaylist(pl.id, track);
              if (context.mounted) {
                _snack(context, 'Добавлено в «$name»');
              }
            },
          ),
          if (lib.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Плейлистов пока нет — создайте первый.',
                style: TextStyle(color: t.textTertiary),
              ),
            ),
          for (final pl in lib.playlists)
            ListTile(
              leading:
                  AppIcon(AppIcons.queue, size: 20, color: t.textSecondary),
              title: Text(pl.name, style: TextStyle(color: t.textPrimary)),
              subtitle: Text('${pl.tracks.length} треков',
                  style: TextStyle(
                      color: t.textTertiary, fontSize: t.caption.fontSize)),
              onTap: () {
                lib.addToPlaylist(pl.id, track);
                Navigator.pop(sheetCtx);
                _snack(context, 'Добавлено в «${pl.name}»');
              },
            ),
        ],
      ),
    ),
  );
}

Future<String?> _askPlaylistName(BuildContext context) {
  final c = TextEditingController();
  final t = SkinScope.maybeOf(context)?.tokens ?? skinFor(SkinId.ios).tokens;
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: t.surfaceAlt,
      title: const Text('Новый плейлист'),
      content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('Создать'),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
