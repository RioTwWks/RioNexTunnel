/// User-facing core engine preference (manual pick or automatic).
enum EnginePreference {
  auto,
  xray,
  singbox;

  String get storageName => name;

  static EnginePreference fromStorage(String? value) {
    switch (value?.toLowerCase()) {
      case 'auto':
        return EnginePreference.auto;
      case 'singbox':
        return EnginePreference.singbox;
      case 'xray':
        return EnginePreference.xray;
      default:
        return EnginePreference.auto;
    }
  }

  bool get isAuto => this == EnginePreference.auto;
}
