import 'package:dio/dio.dart';

import '../../core/net/bff.dart';
import '../../domain/models/playable_stream.dart';
import '../../domain/models/source_type.dart';
import '../../domain/models/track.dart';
import '../../domain/music_source.dart';

/// Источник, у которого ссылка на поток переписана на прокси.
///
/// Обёртка, а не правка каждого источника: браузерный `just_audio` играет через
/// тег `<audio>` и заголовки к потоку не отправляет вовсе — а без них
/// googlevideo и sndcdn отвечают отказом. Поэтому адрес заменяется на
/// подписанную ссылку прокси, который эти заголовки и проставит.
///
/// Всё остальное делегируется как есть, поэтому `Aggregator` и плеер о подмене
/// не знают: пять мест с `AudioSource.uri(..., headers:)` остались нетронутыми.
class ProxiedSource implements MusicSource {
  ProxiedSource(this._inner, this._dio, this._idToken);

  final MusicSource _inner;
  final Dio _dio;
  final Future<String?> Function() _idToken;

  @override
  Future<PlayableStream> resolveStream(Track track) async {
    final direct = await _inner.resolveStream(track);
    if (!hasBff) return direct;

    final token = await _idToken();
    final r = await _dio.post<Map<String, dynamic>>(
      '$kBffUrl/v1/sign',
      data: {
        'url': direct.uri.toString(),
        'headers': direct.headers ?? const <String, String>{},
      },
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );

    final signed = r.data?['url'] as String?;
    if (signed == null) return direct;
    final expiresAtMs = (r.data?['expiresAt'] as num?)?.toInt();

    return PlayableStream(
      uri: Uri.parse('$kBffUrl$signed'),
      // Заголовки уже внутри подписи — клиенту их слать нечем и незачем.
      headers: null,
      // Срок жизни — меньший из двух: протухнет пропуск или сама ссылка
      // источника. По нему плеер сам перерезолвит поток.
      expiresAt: _earliest(direct.expiresAt, expiresAtMs),
    );
  }

  static DateTime? _earliest(DateTime? sourceExpiry, int? tokenExpiryMs) {
    final tokenExpiry = tokenExpiryMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(tokenExpiryMs);
    if (sourceExpiry == null) return tokenExpiry;
    if (tokenExpiry == null) return sourceExpiry;
    return sourceExpiry.isBefore(tokenExpiry) ? sourceExpiry : tokenExpiry;
  }

  // --- Всё остальное — без изменений ---

  @override
  SourceType get type => _inner.type;

  @override
  Future<bool> get isReady => _inner.isReady;

  @override
  bool get supportsPaging => _inner.supportsPaging;

  @override
  Future<List<Track>> search(String query, {int limit = 20, int page = 0}) =>
      _inner.search(query, limit: limit, page: page);

  @override
  Future<List<Track>> feed({int limit = 20}) => _inner.feed(limit: limit);

  @override
  Future<bool> downloadTo(Track track, String path,
          {void Function(int received, int total)? onProgress}) =>
      _inner.downloadTo(track, path, onProgress: onProgress);
}
