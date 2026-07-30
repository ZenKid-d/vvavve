/// Куда прокси вообще имеет право ходить.
///
/// Это главный предохранитель: без него сервис — открытый релей, через который
/// можно долбить любой адрес в интернете с нашего IP. Список закрытый, сверен с
/// тем, что реально дёргает приложение (`grep -rn "https://" lib/data lib/core`).
const allowedHosts = <String>{
  // Источники музыки
  'music.youtube.com',
  'www.youtube.com',
  'youtubei.googleapis.com',
  'api-v2.soundcloud.com',
  'soundcloud.com',
  'api.music.yandex.net',
  'api.vk.com',
  // Обложки и метаданные
  'i.ytimg.com',
  'open.spotify.com',
  // Тексты песен и переводы
  'lrclib.net',
  'api.lyrics.ovh',
  'genius.com',
  'music.163.com',
  'translate.googleapis.com',
  // Скробблинг
  'ws.audioscrobbler.com',
};

/// Домены, любой поддомен которых разрешён: раздача потоков идёт с машин вида
/// `rr3---sn-xxx.googlevideo.com`, перечислить их поимённо невозможно.
const allowedSuffixes = <String>{
  '.googlevideo.com',
  '.sndcdn.com',
  '.vkuseraudio.net',
  '.vk-cdn.net',
  '.storage.mds.yandex.net',
  '.ytimg.com',
  '.scdn.co',
};

bool isAllowedHost(String host) {
  final h = host.toLowerCase();
  if (allowedHosts.contains(h)) return true;
  return allowedSuffixes.any(h.endsWith);
}

/// Заголовки, которые браузер запрещает выставлять из JS и которые прокси
/// восстанавливает по префиксу `X-Fwd-`. Список закрытый: пропускать наружу
/// произвольные заголовки по просьбе клиента — плохая идея.
const restorableHeaders = <String>{
  'user-agent',
  'referer',
  'origin',
  'cookie',
  'authorization',
  'x-goog-visitor-id',
  'x-youtube-client-name',
  'x-youtube-client-version',
  'accept-language',
};
