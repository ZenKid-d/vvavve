class UpdateInfo {
  final String version;
  final String notes;
  final String apkUrl;
  const UpdateInfo(
      {required this.version, required this.notes, required this.apkUrl});
}

/// Репозиторий, из релизов которого приложение тянет обновления.
const kReleasesRepo = 'ZenKid-d/roundds-releases';

/// Строго ли `latest` новее `current` (semver major.minor.patch;
/// нечисловые суффиксы и недостающие компоненты трактуются как 0).
///
/// Наружу выставляется через `UpdateService.isNewer` — она и покрыта тестами.
bool isVersionNewer(String latest, String current) {
  final a = _parts(latest);
  final b = _parts(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int> _parts(String v) {
  final p = v
      .split('.')
      .map((x) => int.tryParse(x.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  while (p.length < 3) {
    p.add(0);
  }
  return p;
}
