/// Фасад входа в аккаунт: на Android — системный диалог Google, в браузере —
/// всплывающее окно Firebase. Наружу оба отдают одинаковый API
/// (см. AuthServiceBase) и общий тип [AppUser].
library;

export 'auth_service_web.dart' if (dart.library.io) 'auth_service_io.dart';
