enum VpnEngine {
  xray('xray'),
  singbox('singbox'),
  skadi('skadi');

  const VpnEngine(this.coreName);

  final String coreName;

  static VpnEngine fromCoreName(String value) {
    switch (value.toLowerCase()) {
      case 'singbox':
        return VpnEngine.singbox;
      case 'skadi':
      case 'skadicore':
        return VpnEngine.skadi;
      case 'xray':
      default:
        return VpnEngine.xray;
    }
  }

  /// Human-readable name for Settings / Home.
  String get displayName {
    switch (this) {
      case VpnEngine.xray:
        return 'Xray';
      case VpnEngine.singbox:
        return 'sing-box';
      case VpnEngine.skadi:
        return 'SkadiCore';
    }
  }
}
