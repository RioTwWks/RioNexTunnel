/// User-facing core engine preference (manual pick or automatic).
enum EnginePreference {
  auto,
  xray,
  singbox,
  skadi;

  String get storageName => name;

  static EnginePreference fromStorage(String? value) {
    switch (value?.toLowerCase()) {
      case 'auto':
        return EnginePreference.auto;
      case 'singbox':
        return EnginePreference.singbox;
      case 'skadi':
        return EnginePreference.skadi;
      case 'xray':
        return EnginePreference.xray;
      default:
        return EnginePreference.auto;
    }
  }

  bool get isAuto => this == EnginePreference.auto;
}
