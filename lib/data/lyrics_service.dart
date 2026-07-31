import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

/// Текст песни: обычный и/или синхронизированный (LRC).
class Lyrics {
  final String? plain;
  final String? synced;
  const Lyrics({this.plain, this.synced});

  bool get isEmpty =>
      (plain == null || plain!.isEmpty) && (synced == null || synced!.isEmpty);
  bool get hasSynced => synced != null && synced!.isNotEmpty;
}

/// Текст песен из нескольких публичных источников (без ключей):
/// lrclib.net → NetEase (music.163.com) → lyrics.ovh.
/// Предпочтение — синхронному тексту (LRC) из любого источника.
class LyricsService {
  LyricsService(this._dio);
  final Dio _dio;

  Future<Lyrics?> fetch({
    required String artist,
    required String title,
    Duration? duration,
  }) async {
    final lrclib = await _lrclib(artist, title, duration);
    if (lrclib != null && lrclib.hasSynced) return lrclib;

    final netease = await _netease(artist, title);
    if (netease != null && netease.hasSynced) return netease;

    if (lrclib != null && !lrclib.isEmpty) return lrclib;
    if (netease != null && !netease.isEmpty) return netease;

    final ovh = await _lyricsOvh(artist, title);
    if (ovh != null && !ovh.isEmpty) return ovh;

    final genius = await _genius(artist, title);
    if (genius != null && !genius.isEmpty) return genius;

    return null;
  }

  // --- lrclib.net ---
  Future<Lyrics?> _lrclib(
      String artist, String title, Duration? duration) async {
    try {
      final r = await _dio.get('https://lrclib.net/api/get', queryParameters: {
        'artist_name': artist,
        'track_name': title,
        if (duration != null) 'duration': duration.inSeconds,
      });
      final d = r.data as Map;
      final lyr = Lyrics(
          plain: d['plainLyrics'] as String?,
          synced: d['syncedLyrics'] as String?);
      if (!lyr.isEmpty) return lyr;
    } catch (_) {/* пробуем поиск */}
    try {
      final r = await _dio.get('https://lrclib.net/api/search',
          queryParameters: {'track_name': title, 'artist_name': artist});
      final list = (r.data as List?) ?? [];
      if (list.isNotEmpty) {
        final d = list.first as Map;
        return Lyrics(
            plain: d['plainLyrics'] as String?,
            synced: d['syncedLyrics'] as String?);
      }
    } catch (_) {}
    return null;
  }

  // --- NetEase (music.163.com), часто есть синхронный LRC ---
  Future<Lyrics?> _netease(String artist, String title) async {
    final opts = Options(headers: const {
      'Referer': 'https://music.163.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    });
    try {
      final s = await _dio.get('https://music.163.com/api/search/get',
          queryParameters: {
            's': '$artist $title',
            'type': 1,
            'limit': 5,
          },
          options: opts);
      final songs = (s.data['result']?['songs'] as List?) ?? [];
      if (songs.isEmpty) return null;
      final id = (songs.first as Map)['id'];
      final l = await _dio.get('https://music.163.com/api/song/lyric',
          queryParameters: {'id': id, 'lv': 1, 'kv': 1, 'tv': -1},
          options: opts);
      final lrc = l.data['lrc']?['lyric'] as String?;
      if (lrc == null || lrc.isEmpty) return null;
      // Есть таймкоды → синхронный, иначе обычный.
      final synced = RegExp(r'\[\d{1,2}:\d{2}').hasMatch(lrc);
      return synced ? Lyrics(synced: lrc) : Lyrics(plain: lrc);
    } catch (_) {
      return null;
    }
  }

  // --- Genius (обычный текст; API не отдаёт текст, поэтому разбор страницы) ---
  Future<Lyrics?> _genius(String artist, String title) async {
    final opts = Options(headers: const {
      'Referer': 'https://genius.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    });
    try {
      final s = await _dio.get('https://genius.com/api/search/multi',
          queryParameters: {'q': '$artist $title'}, options: opts);
      final sections = (s.data['response']?['sections'] as List?) ?? [];
      String? url;
      for (final sec in sections) {
        if ((sec as Map)['type'] == 'song') {
          final hits = (sec['hits'] as List?) ?? [];
          if (hits.isNotEmpty) {
            url = (hits.first as Map)['result']?['url'] as String?;
            break;
          }
        }
      }
      if (url == null) return null;

      final page = await _dio.get<String>(url,
          options: Options(responseType: ResponseType.plain, headers: {
            'User-Agent': opts.headers!['User-Agent'],
          }));
      var body = page.data ?? '';
      // Переносы строк Genius держит в <br> — сохраняем их до разбора.
      body = body.replaceAll(RegExp(r'<br\s*/?>'), '\n');
      final doc = html_parser.parse(body);
      final containers =
          doc.querySelectorAll('[data-lyrics-container="true"]');
      final text = containers.map((e) => e.text).join('\n').trim();
      if (text.isEmpty) return null;
      return Lyrics(plain: text);
    } catch (_) {
      return null;
    }
  }

  // --- lyrics.ovh (обычный текст) ---
  Future<Lyrics?> _lyricsOvh(String artist, String title) async {
    try {
      final r = await _dio.get(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}');
      final plain = r.data['lyrics'] as String?;
      if (plain != null && plain.trim().isNotEmpty) {
        return Lyrics(plain: plain.trim());
      }
    } catch (_) {}
    return null;
  }
}

/// Разобранная строка синхронизированного текста.
class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

/// Парсит LRC ([mm:ss.xx] текст) в отсортированный список строк.
List<LyricLine> parseLrc(String lrc) {
  final out = <LyricLine>[];
  final re = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  for (final raw in lrc.split('\n')) {
    final matches = re.allMatches(raw).toList();
    if (matches.isEmpty) continue;
    final text = raw.replaceAll(re, '').trim();
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final frac = m.group(3);
      final ms = frac == null
          ? 0
          : int.parse(frac.padRight(3, '0').substring(0, 3));
      out.add(LyricLine(
        Duration(minutes: min, seconds: sec, milliseconds: ms),
        text,
      ));
    }
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// Оценка темпа пения: сколько миллисекунд приходится на символ текста.
///
/// В LRC есть только момент НАЧАЛА строки. Если считать, что строка поётся до
/// самой следующей, заливка отстаёт от артиста везде, где между строками есть
/// вдох, проигрыш или пауза: он уже допел, а цвет ещё ползёт.
///
/// Темп берётся из самой песни — по промежуткам между строками. В выборке две
/// разные величины: плотная группа строк, спетых подряд (это и есть темп), и
/// длинный хвост тех, после которых идёт пауза. Поэтому сначала по медиане
/// отбрасывается хвост, а из оставшегося берётся **верхняя** граница группы.
///
/// Именно верхняя, а не средняя: строка без паузы должна окрашиваться ровно всю
/// свою длину. Возьми оценку ниже — и такая строка допоётся раньше, чем её
/// поёт артист, а это заметнее любого отставания.
double estimateMsPerChar(List<LyricLine> lines) {
  const fallback = 85.0; // ≈700 знаков в минуту, обычный темп поп-вокала
  final samples = <double>[];
  for (var i = 0; i + 1 < lines.length; i++) {
    final len = lines[i].text.trim().length;
    if (len < 4) continue; // короткие вроде «Yeah» ничего не говорят о темпе
    final span = (lines[i + 1].time - lines[i].time).inMilliseconds;
    // Промежутки длиннее 15 секунд — это уже проигрыш, а не медленное пение.
    if (span <= 0 || span > 15000) continue;
    samples.add(span / len);
  }
  if (samples.isEmpty) return fallback;
  samples.sort();

  final median = samples[samples.length ~/ 2];
  // Всё, что заметно медленнее середины, — это строки с паузами, а не пение.
  final tight = samples.where((s) => s <= median * 1.5).toList();
  final rate = tight.isEmpty ? median : tight.last;
  return rate.clamp(35.0, 220.0);
}

/// Сколько времени реально поётся строка [i].
///
/// Не дольше, чем до следующей строки (иначе заливка перескочит на чужую), и не
/// быстрее разумного предела — оценка темпа может ошибиться на строке с
/// растянутыми гласными.
Duration singingSpan(List<LyricLine> lines, int i, double msPerChar) {
  if (i < 0 || i >= lines.length) return Duration.zero;
  final len = lines[i].text.trim().length;
  // У последней строки следующей нет: ориентируемся только на длину текста.
  final gap = i + 1 < lines.length
      ? lines[i + 1].time - lines[i].time
      : Duration(milliseconds: (len * msPerChar).round());
  if (gap <= Duration.zero) return Duration.zero;
  if (len == 0) return gap; // пустая строка (♪) — просто ждём следующую

  final estimated = Duration(milliseconds: (len * msPerChar).round());
  // Строка без паузы: оценка дотягивает до следующей строки — окрашиваем её
  // целиком, всю длину. Укорачиваем только там, где дальше явно пауза.
  if (estimated > gap) return gap;
  // Мгновенная вспышка вместо движения не читается как заливка.
  const floor = Duration(milliseconds: 600);
  if (estimated < floor) return gap < floor ? gap : floor;
  return estimated;
}
