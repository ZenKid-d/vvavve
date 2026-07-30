import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service_common.dart';

export 'auth_service_common.dart';

/// Вход через Google в браузере — всплывающим окном Firebase.
///
/// Пакет google_sign_in здесь намеренно не используется: его веб-реализация
/// требует meta-тега с client_id и рисует собственную кнопку GIS вместо
/// программного `signIn()`, то есть тянет за собой переделку интерфейса.
/// `signInWithPopup` не требует ничего, кроме веб-конфига Firebase.
class AuthService extends AuthServiceBase {
  @override
  Future<AppUser?> signIn() async {
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      return currentUser;
    } on FirebaseAuthException catch (e) {
      // Пользователь закрыл окно — это не ошибка, а отказ от входа.
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return null;
      }
      if (e.code == 'popup-blocked') {
        throw const AuthFailure(
            'Браузер заблокировал всплывающее окно — разреши его для этого сайта');
      }
      if (e.code == 'unauthorized-domain') {
        throw const AuthFailure(
            'Домен не разрешён в Firebase → Authentication → Settings');
      }
      throw AuthFailure(e.message ?? 'Не удалось войти');
    }
  }
}
