import 'source_type.dart';
import 'track.dart';

/// Альбом из выдачи поиска (не трек) — YouTube Music и SoundCloud отдают
/// альбомы отдельно от отдельных песен. Треклист открывается через
/// [AlbumScreen] по «зерну» — синтетическому [Track] с [Track.album],
/// который дальше идёт по обычному фолбэк-пути Aggregator.albumTracks
/// (поиск «артист альбом» по включённым источникам).
class AlbumResult {
  const AlbumResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    this.artworkUrl,
    this.trackCount,
  });

  /// Идентификатор альбома внутри источника (browseId у YT Music, id
  /// плейлиста-альбома у SoundCloud). Сейчас используется только для дедупа —
  /// нативного треклиста по этому id источники пока не отдают.
  final String id;
  final String title;
  final String artist;
  final SourceType source;
  final String? artworkUrl;
  final int? trackCount;

  String get uid => '${source.id}:album:$id';

  /// Синтетический трек-«зерно» для [AlbumScreen]: даёт заголовку/фолбэк-поиску
  /// артиста и название альбома, но сам не играбелен и в очередь не идёт.
  Track toSeedTrack() => Track(
        id: 'album_$id',
        title: title,
        artist: artist,
        album: title,
        artworkUrl: artworkUrl,
        source: source,
      );
}
