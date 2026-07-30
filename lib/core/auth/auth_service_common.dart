import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';

export 'app_user.dart';

/// Общая часть входа: всё, кроме самого получения учётных данных Google —
/// оно на Android и в браузере устроено принципиально по-разному (см.
/// auth_service_io.dart / auth_service_web.dart).
abstract class AuthServiceBase {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Текущий пользователь и все его смены. Первое значение приходит сразу
  /// после восстановления сессии, поэтому UI не мигает «не вошёл».
  Stream<AppUser?> get authState =>
      _auth.authStateChanges().map(_toAppUser);

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  bool get signedIn => _auth.currentUser != null;

  /// Вход через Google. Реализация платформенная.
  Future<AppUser?> signIn();

  Future<void> signOut() => _auth.signOut();

  /// Токен для запросов к своему прокси-серверу: тот проверяет подпись и
  /// принадлежность проекту, поэтому открытым релеем не становится.
  /// [force] обновляет токен, не дожидаясь истечения.
  Future<String?> idToken({bool force = false}) async =>
      _auth.currentUser?.getIdToken(force);

  AppUser? _toAppUser(User? u) => u == null
      ? null
      : AppUser(
          uid: u.uid,
          displayName: u.displayName,
          email: u.email,
          photoUrl: u.photoURL,
        );
}

/// Вход не удался по вине окружения (нет сети, отменён пользователем,
/// не совпал SHA-1). Отделяем от прочих ошибок, чтобы UI показал понятное.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
