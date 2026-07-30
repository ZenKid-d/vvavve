/// Адрес прокси-сервера веб-версии.
///
/// Задаётся при сборке: `flutter build web --dart-define=BFF_URL=https://…`.
/// Пустое значение означает «прокси нет» — на Android так и есть, там
/// приложение ходит к источникам напрямую.
const String kBffUrl = String.fromEnvironment('BFF_URL');

bool get hasBff => kBffUrl.isNotEmpty;

/// Заголовки, которые браузер запрещает выставлять из JS. Клиент перекладывает
/// их в `X-Fwd-*`, прокси возвращает на место. Без этого источники отвечают
/// отказом: InnerTube проверяет Origin и Referer, остальные — User-Agent.
const forbiddenInBrowser = <String>{
  'user-agent',
  'referer',
  'origin',
  'cookie',
};

/// Адрес запроса, переписанный на прокси.
String proxiedApiUrl(String absoluteUrl) =>
    '$kBffUrl/v1/api?u=${Uri.encodeComponent(absoluteUrl)}';
