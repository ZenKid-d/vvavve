/// Кто вошёл. Минимум, который нужен UI, — без зависимости от типов Firebase,
/// чтобы экраны не знали, чем именно сделан вход.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  /// Идентификатор аккаунта — им же адресуются данные в Firestore
  /// (`users/{uid}/...`).
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// Что показать в интерфейсе: имя, почта или обрезанный uid — но не пусто.
  String get label {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = email?.trim();
    if (e != null && e.isNotEmpty) return e;
    return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
  }
}
