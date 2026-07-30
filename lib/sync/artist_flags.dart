/// Отношение к артисту одной записью: подписка и чёрный список.
///
/// Раньше это были два независимых списка в разных ключах, причём один хранил
/// отображаемые имена, другой — приведённые к нижнему регистру. Для
/// синхронизации это неудобно: два списка про один и тот же объект дают два
/// конфликта вместо одного. Ключ записи — имя в нижнем регистре, отображаемое
/// написание лежит внутри.
class ArtistFlags {
  const ArtistFlags({
    required this.name,
    this.followed = false,
    this.blacklisted = false,
  });

  /// Как показывать пользователю (регистр авторский).
  final String name;
  final bool followed;
  final bool blacklisted;

  /// Ключ записи — регистр в нём не участвует.
  static String keyOf(String name) => name.trim().toLowerCase();

  String get key => keyOf(name);

  /// Запись без флагов бессмысленна — её место занимает надгробие.
  bool get isEmpty => !followed && !blacklisted;

  ArtistFlags copyWith({String? name, bool? followed, bool? blacklisted}) =>
      ArtistFlags(
        name: name ?? this.name,
        followed: followed ?? this.followed,
        blacklisted: blacklisted ?? this.blacklisted,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (followed) 'followed': true,
        if (blacklisted) 'blacklisted': true,
      };

  static ArtistFlags fromJson(Map<String, dynamic> j) => ArtistFlags(
        name: j['name'] as String? ?? '',
        followed: j['followed'] == true,
        blacklisted: j['blacklisted'] == true,
      );
}
