/// Одна синхронизируемая запись: значение плюс то, что нужно для слияния.
///
/// Удаление хранится как «надгробие» ([deleted]) с новой меткой времени, а не
/// исчезновением записи. Без этого снятый лайк неотличим от лайка, которого
/// никогда не было, и любое слияние воскрешало бы его с другого устройства.
class SyncedRecord<T> {
  const SyncedRecord({
    required this.key,
    required this.updatedAt,
    this.value,
    this.deleted = false,
    this.origin,
  });

  /// Ключ записи: uid трека/альбома или нормализованное имя артиста.
  final String key;

  /// Значение. null у надгробия — payload удалённой записи не хранится.
  final T? value;

  /// Когда запись изменилась в последний раз (epoch ms, часы устройства).
  final int updatedAt;

  final bool deleted;

  /// Устройство, сделавшее правку. Нужно только чтобы одинаковые метки
  /// времени разрешались одинаково на всех устройствах, а не по-разному.
  final String? origin;

  SyncedRecord<T> tombstone(int at, {String? origin}) => SyncedRecord<T>(
        key: key,
        updatedAt: at,
        deleted: true,
        origin: origin ?? this.origin,
      );

  /// Выигрывает ли [other] у этой записи. При равных метках побеждает больший
  /// origin — произвольное, но одинаковое на всех устройствах правило, иначе
  /// два устройства могут разойтись навсегда.
  bool losesTo(SyncedRecord<T> other) {
    if (other.updatedAt != updatedAt) return other.updatedAt > updatedAt;
    return (other.origin ?? '').compareTo(origin ?? '') > 0;
  }

  Map<String, dynamic> toJson(Object? Function(T value) encode) => {
        'k': key,
        'u': updatedAt,
        if (deleted) 'd': true,
        if (!deleted && value != null) 'p': encode(value as T),
        if (origin != null) 'o': origin,
      };

  static SyncedRecord<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) decode,
  ) {
    final deleted = json['d'] == true;
    final payload = json['p'];
    return SyncedRecord<T>(
      key: json['k'] as String,
      updatedAt: (json['u'] as num).toInt(),
      deleted: deleted,
      origin: json['o'] as String?,
      value: deleted || payload == null
          ? null
          : decode((payload as Map).cast<String, dynamic>()),
    );
  }
}
