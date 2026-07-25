import 'source_type.dart';
import 'track.dart';

/// Альбом из выдачи поиска (не трек) — YouTube Music и SoundCloud отдают
/// альбомы отдельно от отдельных песен. Треклист открывается через
/// [AlbumScreen] по «зерну» — синтетическому [Track] с [Track.album] и
/// albumId в extra, по которому Aggregator.albumTracks забирает точный
/// треклист напрямую у источника (см. YoutubeMusicSource.albumTracks /
/// SoundcloudSource.albumTracks).
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
  /// плейлиста-альбома у SoundCloud).
  final String id;
  final String title;
  final String artist;
  final SourceType source;
  final String? artworkUrl;
  final int? trackCount;

  String get uid => '${source.id}:album:$id';

  /// Синтетический трек-«зерно» для [AlbumScreen]: даёт заголовок и albumId
  /// для точного треклиста, но сам не играбелен и в очередь не идёт.
  Track toSeedTrack() => Track(
        id: 'album_$id',
        title: title,
        artist: artist,
        album: title,
        artworkUrl: artworkUrl,
        source: source,
        extra: {'albumId': id},
      );

  /// Восстанавливает идентичность альбома из «зерна» [AlbumScreen] — нужен
  /// для лайка/дизлайка, когда экран открыли не из поиска (там albumId в
  /// extra есть), а из меню обычного трека («Открыть альбом»), где известны
  /// только артист/название/источник. В этом случае id — нормализованный
  /// ключ «артист|альбом» (стабильный для одного и того же альбома между
  /// открытиями, но не привязанный к реальному id источника).
  factory AlbumResult.fromSeed(Track seed) {
    final albumId = seed.extra['albumId'] as String?;
    final title =
        (seed.album != null && seed.album!.isNotEmpty) ? seed.album! : seed.title;
    final id = albumId ??
        '${seed.artist.trim().toLowerCase()}|${title.trim().toLowerCase()}';
    return AlbumResult(
      id: id,
      title: title,
      artist: seed.artist,
      source: seed.source,
      artworkUrl: seed.artworkUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'source': source.id,
        'artworkUrl': artworkUrl,
        'trackCount': trackCount,
      };

  factory AlbumResult.fromJson(Map<String, dynamic> j) => AlbumResult(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        source: SourceTypeX.fromId(j['source'] as String? ?? 'youtube'),
        artworkUrl: j['artworkUrl'] as String?,
        trackCount: (j['trackCount'] as num?)?.toInt(),
      );
}
