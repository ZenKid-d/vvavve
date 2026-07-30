/// Имя недоступного хоста из сообщения об ошибке (для диагностики), напр.
/// `Failed host lookup: 'api-v2.soundcloud.com'` → `api-v2.soundcloud.com`.
/// null — если в тексте хоста нет.
///
/// Чистая работа со строкой, одинаковая на всех платформах.
String? blockedHostOf(Object error) {
  final m =
      RegExp("Failed host lookup: '([^']+)'").firstMatch(error.toString());
  return m?.group(1);
}
