import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service_common.dart';
import 'google_sign_in_shared.dart';

export 'auth_service_common.dart';

/// Вход через Google на Android: аккаунт выбирается системным диалогом
/// (google_sign_in), а его токены обмениваются на сессию Firebase.
class AuthService extends AuthServiceBase {
  @override
  Future<AppUser?> signIn() async {
    final account = await sharedGoogleSignIn.signIn();
    if (account == null) return null; // пользователь закрыл диалог выбора
    final auth = await account.authentication;
    if (auth.idToken == null) {
      // Практически всегда означает, что SHA-1 этой сборки не добавлен в
      // Firebase: диалог проходит, но токен не выдаётся.
      throw const AuthFailure(
          'Google не выдал токен — проверь SHA-1 сборки в настройках Firebase');
    }
    final cred = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
    await FirebaseAuth.instance.signInWithCredential(cred);
    return currentUser;
  }

  /// Выходим и из Google тоже — иначе следующий вход молча возьмёт тот же
  /// аккаунт, и сменить его будет нечем.
  @override
  Future<void> signOut() async {
    try {
      await sharedGoogleSignIn.signOut();
    } catch (_) {/* не критично: сессия Firebase всё равно закрывается ниже */}
    await super.signOut();
  }
}
