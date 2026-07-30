# Веб-версия и синхронизация

Живой документ по переносу vvavve в браузер и синхронизации библиотеки между
устройствами. План целиком — в `~/.claude/plans/vvavve-functional-cosmos.md`;
здесь только то, что нужно человеку, который собирает проект.

## Что уже сделано

**Этап 0 — платформенные фасады.** Код перестал зависеть от `dart:io` там, где
это мешало веб-сборке. Поведение на Android не изменилось.

Идиома везде одна: `foo.dart` — фасад с условным экспортом, `foo_io.dart` —
сегодняшняя реализация, `foo_web.dart` — веб-вариант. Веб выбран веткой по
умолчанию (`export 'foo_web.dart' if (dart.library.io) 'foo_io.dart'`), чтобы
новая неподдержанная платформа деградировала, а не падала на разрешении импортов.

Железное правило: **в публичных сигнатурах фасада не должно быть типов из
`dart:io`** — иначе фасад не компилируется под web. Из-за этого
`buildDohDioAdapter` теперь возвращает базовый `HttpClientAdapter?` (на вебе
`null`, и dio сам берёт браузерный адаптер), а `buildDohHttpClient` и
`Storage.dirSize(Directory)` наружу не выносятся вообще.

| Фасад | На Android | В браузере |
|---|---|---|
| `core/net/doh_http.dart` | DoH + HTTP-прокси | обхода нет (его роль берёт BFF) |
| `core/net/net_errors.dart` | `SocketException` + errno | проверка по тексту |
| `core/storage.dart` | размер кэша по файлам | размер всегда 0, очистка работает |
| `core/update_service.dart` | скачивание и установка APK | заглушка, баннер не появляется |
| `core/downloads_controller.dart` | офлайн-загрузки | заглушка с тем же API |
| `core/io/file_io.dart` | временный файл + «Поделиться» | отдача из памяти |
| `data/sources/yt_download.dart` | запись потока в файл | всегда `false` |
| `data/recs/db_factory.dart` | нативный sqflite | sqlite3-wasm поверх IndexedDB |

Попутно сняты два блокера, которые снаружи не видны:

- `RecsStore` больше не использует `dart:isolate` — вместо `Isolate.run` вызов
  `compute` с top-level функцией `buildProfileOffThread`. На мобильном это тот
  же изолейт, на вебе вычисление идёт на месте.
- `RecsDb`/`RecsStore` перешли с типов `package:sqflite` на `sqflite_common`:
  `Database` и `DatabaseFactory` у нативной и wasm-реализации одни и те же,
  поэтому полтора десятка мест с сырыми запросами переписывать не пришлось.

Выбор файла реализации делает компилятор, поэтому веб-заглушки в APK не
попадают, а io-код — в веб-бандл.

## Разовые шаги перед первой веб-сборкой

1. Сгенерировать платформенную часть: `flutter create --platforms=web .`
2. Положить sqlite3 в `web/` (иначе `recs.db` в браузере не откроется):
   ```bash
   dart run sqflite_common_ffi_web:setup
   ```
   Кладёт `sqlite3.wasm` и `sqflite_sw.js`. Повторять после обновления пакета.
3. Собирать с версией в окружении — `package_info_plus` на вебе отдаёт заглушку,
   и `UpdateService.currentVersion()` берёт значение отсюда:
   ```bash
   flutter build web --release --dart-define=APP_VERSION=3.2.2
   ```

Для GitHub Pages добавляется `--base-href /vvavve/`, а `index.html` копируется в
`404.html`, иначе прямой заход на маршрут `go_router` даст 404.

## Firebase

Проект `count0-8424b`. Конфигурацию генерирует `flutterfire configure`
(`lib/firebase_options.dart` + `android/app/google-services.json`) — оба файла
коммитятся: там публичные идентификаторы, а настоящая граница безопасности —
правила Firestore.

Вход через Google сделан фасадом `core/auth/auth_service.dart`: на Android это
системный диалог `google_sign_in`, чьи токены обмениваются на сессию Firebase,
в браузере — `signInWithPopup` (веб-реализация `google_sign_in` потребовала бы
meta-тега с client_id и своей кнопки GIS). Экземпляр `GoogleSignIn` теперь один
на приложение (`core/auth/google_sign_in_shared.dart`): раньше импорт лайков
YouTube держал собственный, а два экземпляра делят один аккаунт и незаметно
ломают друг другу `signOut`. Скоуп `youtube.readonly` при обычном входе не
запрашивается — он чувствительный, и его наличие потребовало бы верификации
приложения у Google.

**Правила Firestore лежат в `firestore.rules` и должны быть опубликованы**,
иначе база останется с дефолтными (заблокированными или, хуже, открытыми):

```bash
firebase deploy --only firestore:rules
```

Без входа приложение работает полностью — синхронизация только добавляется.

## Что дальше

Ближайший этап — «веб собирается»: разделение `main.dart` на `bootstrap.dart` +
`main.dart` + `main_web.dart` и скрытие того, чего в браузере нет (эквалайзер,
хранилище, загрузки, визуализатор, обновления). Дальше — прокси-сервер, без
которого поиск и звук в браузере невозможны из-за CORS и запрета браузера на
заголовки `User-Agent`/`Referer`/`Origin`.
