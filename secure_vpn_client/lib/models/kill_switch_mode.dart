enum KillSwitchMode {
  off,
  strict,
  adaptive;

  static const storageKey = 'kill_switch_mode';

  String get storageName => name;

  static KillSwitchMode fromStorage(String? value) {
    if (value == null) {
      return KillSwitchMode.off;
    }
    return KillSwitchMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => KillSwitchMode.off,
    );
  }

  bool get isStrict => this == KillSwitchMode.strict;

  bool get isEnabled => this != KillSwitchMode.off;
}
