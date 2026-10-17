# Roundds Implementation TODO

## Backlog (from ROADMAP.md) - Priority Features

### 1. Real Crossfade with Two Players (Medium) - PARTIAL (fade-lite, not true dual-player)
- [x] Crossfade duration setting (in settings)
- [x] Volume fade in/out on a single player near track boundaries (`_fadeTimer`
      in `audio_handler.dart`), compatible with gapless
- [ ] Actual dual-player crossfade (two AudioPlayer instances overlapping) -
      декомпозиция в ROADMAP.md (Бэклог), требует рефакторинг ядра

### 2. Local Files Support (Medium) - DONE
- [x] Manifest: READ_MEDIA_AUDIO (13+) + READ_EXTERNAL_STORAGE (≤32)
- [x] LocalFilesSource implementing MusicSource (dart:io-скан, кэш, права)
- [x] Aggregator wiring + синглтон-провайдер
- [x] Метадата из имени файла («Артист — Название»), 8 расширений аудио
- [x] Вкладка «На устройстве» в медиатеке с lazy-сканом и invalidate
- [x] Переключатель источника появился сам (SourceTypeValues экстерна)
- [x] 11 тестов: разбор имён, скан/фильтры, права, resolve/delete
- [ ] MediaStore-скан (MethodChannel) — optional, см. ROADMAP
- [ ] ID3-теги (опционально; сейчас имя файла)
- [x] Тумблер источника в Настройках (SourceType.local появился сам, 
      подсказка в SettingsCopy.sourceHint)

### 3. Album Pages (Low) - DONE (было готово раньше, ROADMAP отставал)
- [x] AlbumScreen с треклистом + лайк/дизлайк альбома, радио, скачать
- [x] Открытие из карточек, меню плеера, артиста, мини-плейлистов (6 мест)
- [x] Треки альбома из нативного источника (Яндекс) с фолбэком на поиск

### 4. Home Widget / Notification Tile (Medium)
- [ ] Add home_widget dependency
- [ ] Create widget layout (play/pause, next, prev, track info, artwork)
- [ ] Implement widget update service
- [ ] Connect with audio_handler for state updates
- [ ] Add widget configuration (size, transparency)
- [ ] Test on different Android versions

### 5. Android Auto (High) - Deferred to later sprint

## New Features - High Impact UX

### 6. Smart Queue with Long Press Actions
- [ ] Add LongPressDraggable to TrackCard
- [ ] Create QueueActionBottomSheet with: Play Next, Add to Queue, Add to Playlist, Download, Share, Remove
- [ ] Integrate with PlaybackController
- [ ] Add haptic feedback on long press

### 7. Swipe Gestures in Queue
- [ ] Implement Dismissible in queue list items
- [ ] Swipe left: Remove from queue
- [ ] Swipe right: "Play Next" (move to position after current)
- [ ] Add undo snackbar for accidental swipes

### 8. Filters/Sorting in Playlists and Likes
- [ ] Add sort options: Date Added, Alphabetical, Duration, Source, Artist
- [ ] Add filter by: Source, Downloaded, Liked
- [ ] Persist sort/filter preferences per playlist
- [ ] Add sort/filter toolbar to TrackListScreen

### 9. Search Within Playlist/Queue
- [ ] Add search field to TrackListScreen app bar (pull-down or persistent)
- [ ] Implement real-time filtering
- [ ] Highlight matching text
- [ ] Add "Clear search" action

### 10. Group Actions (Multi-select)
- [ ] Add selection mode to TrackListScreen (long press to enter)
- [ ] Selection toolbar: Add to Playlist, Download, Remove, Share
- [ ] Visual feedback for selected items
- [ ] Exit selection mode on back press or "Done"

### 11. Audio-Only Mode for YouTube
- [ ] Add setting toggle "Audio Only (Save Data)"
- [ ] Modify YoutubeMusicSource to request audio-only streams
- [ ] Update stream quality selection to reflect audio-only bitrates
- [ ] Show data savings indicator

### 12. Persistent Mini-Player ✅ DONE (core), minor polish left
- [x] HomeShell shows MiniPlayer whenever there's a current track
      (`lib/core/widgets/mini_player.dart` + `lib/features/shell/home_shell.dart`)
- [x] Tap / swipe-up on mini-player → expand to NowPlayingScreen (`context.push('/player')`)
- [x] Persists across navigation (lives in HomeShell, not per-tab)
- [ ] Entrance/exit animation (currently just appears/disappears, no transition)

### 13. Haptic Feedback
- [ ] Add vibration feedback to: Play/Pause, Next/Prev, Like, Seek, Long press
- [ ] Use HapticFeedback.mediumImpact for primary actions
- [ ] Use HapticFeedback.lightImpact for secondary actions
- [ ] Respect system haptic settings

### 14. Landscape Mode for NowPlaying
- [ ] Create responsive NowPlayingLayout
- [ ] Landscape: Vinyl/Artwork full height, controls overlay
- [ ] Portrait: Current layout
- [ ] Smooth transition on rotation
- [ ] Lock screen orientation option in settings

## Technical Debt / Infrastructure

### 15. Riverpod 3 / go_router 17 Migration
- [ ] Update dependencies
- [ ] Fix breaking API changes
- [ ] Run tests

### 16. Palette Generator Replacement
- [ ] Research alternatives (image_palette, custom k-means)
- [ ] Implement replacement
- [ ] Ensure dynamic accent still works

### 17. Code Generation (freezed/json_serializable)
- [ ] Add dependencies
- [ ] Annotate models (Track, Playlist, etc.)
- [ ] Run build_runner
- [ ] Remove manual fromJson/toJson

## Testing & Quality

### 18. Unit/Widget Tests
- [ ] Test Aggregator fallback logic
- [ ] Test AudioHandler crossfade/gapless
- [ ] Test RecommendationService
- [ ] Test DownloadsController
- [ ] Widget tests for key screens

### 19. CI Integration Tests
- [ ] Set up emulator in CI
- [ ] Run integration tests on push

### 20. i18n — IN PROGRESS (infra done, screens pending)
- [x] flutter_localizations/intl + l10n.yaml + lib/l10n/app_ru.arb (source) +
      app_en.arb (translation), MaterialApp wired to AppLocalizations
- [x] Pilot screen migrated: app_drawer.dart (nav labels, service status)
- [ ] home_screen.dart (478 lines — largest untouched, high visibility)
- [ ] now_playing_screen.dart (663 lines)
- [ ] library_screen.dart (1050 lines — largest in the app)
- [ ] settings_screen.dart (886 lines)
- [ ] remaining ~15 smaller screens/widgets with hardcoded RU strings
- Each screen should land as its own commit + `dart analyze` + `flutter test`
  pass before moving to the next — do not batch multiple large screens
  into one unverified diff.