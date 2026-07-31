import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/providers.dart';
import '../../core/theme/accent_provider.dart';
import '../../core/widgets/karaoke_backdrop.dart';
import '../../core/widgets/karaoke_line.dart';
import '../../data/lyrics_service.dart';
import '../../data/visualizer_session.dart';
import '../../domain/models/track.dart';

/// Экран текста песни: полноэкранный. Если есть синхронный текст (LRC) —
/// «караоке» с заливкой строки в такт, авто-прокруткой по центру и живым фоном
/// из акцентных цветов; иначе — обычный текст поверх размытой обложки (по
/// цепочке источников, включая Genius). Открывается по умолчанию вместо
/// обычного текста.
class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key, required this.track});
  final Track track;

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  Lyrics? _lyrics;
  List<LyricLine> _lines = [];
  bool _loading = true;
  int _active = -1;
  final _activeKey = GlobalKey();
  final _scroll = ScrollController();
  bool _translate = false;
  final Map<int, String> _tr = {}; // перевод по индексу строки
  int _offsetMs = 0; // ручная подстройка синхронизации

  /// Трек, для которого сейчас показан текст. Экран открывается для
  /// конкретного трека, но остаётся открытым и когда очередь идёт дальше —
  /// тогда он должен показывать уже новый текст, а не прошлый.
  late Track _track = widget.track;

  /// Номер загрузки: ответ на запрос по прошлому треку может прийти после
  /// того, как трек уже сменился, и затереть актуальный текст.
  int _fetchGen = 0;

  /// Темп пения этой песни — оценивается один раз по её же разметке.
  double _msPerChar = 85;

  /// Номер активной строки для фона.
  ///
  /// Отдельным ValueNotifier, а не полем: активная строка вычисляется внутри
  /// билдера списка, и присваивание полю корневой build не перестраивает —
  /// фон узнавал бы о смене строки только когда что-то другое перерисует
  /// экран. Уведомление доставляет изменение адресно, не трогая список.
  final _beat = ValueNotifier<int>(-1);

  /// Поток полос спектра, если реальный анализ доступен: тогда фон пульсирует
  /// по самому звуку, а не по строкам.
  Stream<List<double>>? _spectrum;
  bool _spectrumHeld = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _maybeUseSpectrum();
  }

  /// Подключает реальный спектр — если пользователь уже включил визуализатор и
  /// разрешил микрофон.
  ///
  /// Разрешение здесь намеренно НЕ запрашивается: системный диалог про
  /// микрофон, всплывший при открытии текста песни, выглядел бы как минимум
  /// странно. Не сложилось — фон пульсирует по строкам, и это не хуже.
  Future<void> _maybeUseSpectrum() async {
    if (kIsWeb) return; // нативного анализа в браузере нет
    if (!(ref.read(prefsProvider).getBool('real_visualizer') ?? false)) return;
    if (!await Permission.microphone.isGranted) return;

    final sid = ref.read(audioHandlerProvider).androidAudioSessionId ?? 0;
    final bands = await VisualizerSession.instance.acquire(sid);
    if (!mounted) {
      if (bands != null) VisualizerSession.instance.release();
      return;
    }
    if (bands == null) return;
    _spectrumHeld = true;
    setState(() => _spectrum = bands);
  }

  /// Следит за сменой трека в плеере.
  void _syncWithPlayer() {
    final current = ref.watch(playbackProvider).current;
    if (current == null || current.uid == _track.uid) return;
    _track = current;
    // Прошлый текст убираем сразу: показывать чужие строки под новую песню
    // хуже, чем показать загрузку.
    _lyrics = null;
    _lines = const [];
    _tr.clear();
    _active = -1;
    _beat.value = -1;
    _offsetMs = 0; // подстройка синхронизации относится к прошлой песне
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    final gen = ++_fetchGen;
    final track = _track;
    final l = await ref.read(lyricsServiceProvider).fetch(
          artist: track.artist,
          title: track.title,
          duration: track.duration,
        );
    if (!mounted || gen != _fetchGen) return;
    setState(() {
      _lyrics = l;
      _lines = (l?.hasSynced ?? false) ? parseLrc(l!.synced!) : [];
      _msPerChar = estimateMsPerChar(_lines);
      _loading = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    // Сессию обязательно отпустить: захват общий, и незакрытая ссылка держала
    // бы нативный анализ включённым после ухода с экрана.
    if (_spectrumHeld) VisualizerSession.instance.release();
    _beat.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Насколько спета строка [i] к моменту [pos], 0..1.
  ///
  /// Заливка идёт не до следующей строки, а ровно столько, сколько строка
  /// поётся: в LRC записан только момент начала, и растягивание на весь
  /// промежуток заставляло цвет ползти всё время вдоха или проигрыша, отставая
  /// от артиста. Длительность оценивается по длине текста и темпу самой песни
  /// (см. [singingSpan]).
  double _progressAt(int i, Duration pos) {
    if (i < 0 || i >= _lines.length) return 0;
    final start = _lines[i].time;
    final span = singingSpan(_lines, i, _msPerChar).inMilliseconds;
    if (span <= 0) return 1;
    return ((pos - start).inMilliseconds / span).clamp(0.0, 1.0);
  }

  int _lineFor(Duration pos) {
    var idx = -1;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].time <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _centerActive() {
    final ctx = _activeKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Акцент берём из провайдера, а не из темы: в динамическом режиме он
    // вытянут из обложки играющего трека, и заливка текста попадает в его
    // палитру. Тема же отражает выбранный режим оформления в целом.
    final accent = ref.watch(effectiveAccentProvider);
    _syncWithPlayer();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // В караоке фон живой и целиком из акцента; статичный текст — на
          // размытой обложке, как было. Причина в читаемости: обложка даёт
          // случайные светлые пятна, на которых белые буквы пропадают, и это
          // особенно мешает, когда взгляд бежит по строкам за музыкой.
          if (_lines.isNotEmpty)
            ValueListenableBuilder<int>(
              valueListenable: _beat,
              builder: (context, beat, _) => KaraokeBackdrop(
                accent: accent,
                playing: ref.watch(playbackProvider).isPlaying,
                // Есть спектр — пульс идёт по низким частотам, то есть по
                // настоящему биту. Нет — по смене строки: это разметка самой
                // песни, так что отклик всё равно попадает в музыку.
                spectrum: _spectrum,
                beat: beat,
              ),
            )
          else ...[
            if (_track.artworkUrl != null)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: CachedNetworkImage(
                    imageUrl: _track.artworkUrl!, fit: BoxFit.cover),
              ),
            Container(color: Colors.black.withValues(alpha: 0.76)),
          ],
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                if (!_loading && _lines.isNotEmpty) _syncBar(),
                Expanded(child: _body(accent)),
                if (!_loading &&
                    _lyrics != null &&
                    !_lyrics!.isEmpty)
                  _controls(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_lines.isNotEmpty)
            IconButton(
              tooltip: 'Перевод строки',
              icon: Icon(Icons.translate,
                  size: 20,
                  color: _translate ? Colors.white : Colors.white38),
              onPressed: () => setState(() => _translate = !_translate),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(_lines.isNotEmpty ? 'КАРАОКЕ' : 'ТЕКСТ',
                style: const TextStyle(
                    fontSize: 10.5, letterSpacing: 1.5, color: Colors.white54)),
          ),
        ],
      );

  // Тонкая панель подстройки синхронизации текста (± шаг 0.3 с).
  Widget _syncBar() {
    final off = (_offsetMs / 1000).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Синхрон',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18, color: Colors.white70),
            onPressed: () => setState(() => _offsetMs -= 300),
          ),
          SizedBox(
            width: 52,
            child: Text('${_offsetMs > 0 ? '+' : ''}$off с',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18, color: Colors.white70),
            onPressed: () => setState(() => _offsetMs += 300),
          ),
          if (_offsetMs != 0)
            TextButton(
              onPressed: () => setState(() => _offsetMs = 0),
              child: const Text('Сброс', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _body(Color accent) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_lyrics == null || _lyrics!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('Текст не найден',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        ),
      );
    }
    if (_lines.isNotEmpty) return _synced(accent);
    return _plain();
  }

  // Синхронный «караоке»: центрированные строки с плавной подсветкой.
  Widget _synced(Color accent) {
    return Consumer(builder: (context, ref, _) {
      final rawPos = ref.watch(positionProvider).value ??
          ref.read(playbackProvider).position;
      final pos = rawPos - Duration(milliseconds: _offsetMs);
      final idx = _lineFor(pos);
      if (idx != _active) {
        _active = idx;
        // Оба действия — следующим кадром: менять состояние прямо во время
        // сборки нельзя, а фон и прокрутка подождут один кадр без потерь.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _centerActive();
          _beat.value = idx;
        });
      }
      // Ленивый перевод активной строки.
      if (_translate &&
          idx >= 0 &&
          idx < _lines.length &&
          !_tr.containsKey(idx)) {
        _tr[idx] = '';
        ref
            .read(translationServiceProvider)
            .toRussian(_lines[idx].text)
            .then((t) {
          if (mounted) setState(() => _tr[idx] = t ?? '');
        });
      }
      final vpad = MediaQuery.of(context).size.height * 0.42;
      return ListView.builder(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: vpad, horizontal: 28),
        itemCount: _lines.length,
        itemBuilder: (_, i) {
          final active = i == idx;
          final dist = (i - idx).abs();
          final dim = active
              ? 1.0
              : dist == 1
                  ? 0.55
                  : dist == 2
                      ? 0.38
                      : 0.24;
          final translated = _tr[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(playbackProvider).seek(_lines[i].time),
            child: Container(
              key: active ? _activeKey : null,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KaraokeLine(
                    text: _lines[i].text.isEmpty ? '♪' : _lines[i].text,
                    accent: accent,
                    active: active,
                    progress: active ? _progressAt(i, pos) : 0,
                    dim: dim,
                  ),
                  if (_translate &&
                      active &&
                      translated != null &&
                      translated.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        translated,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  // Обычный текст (без синхронизации).
  Widget _plain() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Text(
        _lyrics!.plain ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }

  Widget _controls(Color accent) {
    return Consumer(builder: (context, ref, _) {
      final pc = ref.watch(playbackProvider);
      final pos = ref.watch(positionProvider).value ?? Duration.zero;
      final dur = pc.duration;
      final max = dur.inMilliseconds.toDouble();
      final value = pos.inMilliseconds.clamp(0, max <= 0 ? 1 : max).toDouble();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: max > 0 ? value : 0,
                max: max > 0 ? max : 1,
                onChanged: (v) => pc.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: pc.previous),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: pc.togglePlay,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                    child: Icon(pc.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 30, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_next),
                    onPressed: pc.next),
              ],
            ),
          ],
        ),
      );
    });
  }
}
