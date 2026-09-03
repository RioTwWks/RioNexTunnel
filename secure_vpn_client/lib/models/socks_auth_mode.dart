/// How local SOCKS5 credentials are chosen before connect.
enum SocksAuthMode {
  randomPerSession,
  staticFromPanel,
  disableInjection;

  String get storageName => name;

  static SocksAuthMode fromStorage(String? value) {
    switch (value) {
      case 'staticFromPanel':
        return SocksAuthMode.staticFromPanel;
      case 'disableInjection':
        return SocksAuthMode.disableInjection;
      case 'randomPerSession':
      default:
        return SocksAuthMode.randomPerSession;
    }
  }

  bool get isRandom => this == SocksAuthMode.randomPerSession;
  bool get isStaticFromPanel => this == SocksAuthMode.staticFromPanel;
  bool get isDisableInjection => this == SocksAuthMode.disableInjection;
}
