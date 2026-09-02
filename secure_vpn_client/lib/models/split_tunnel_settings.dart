import 'package:v2ray_box/v2ray_box.dart';

/// Per-app split tunneling: route selected apps through VPN or direct.
///
/// Maps to [PerAppProxyMode] in the v2ray_box plugin:
/// - [off] — all apps use the VPN tunnel (default)
/// - [include] — whitelist: only listed apps use VPN
/// - [exclude] — blacklist: listed apps bypass VPN
enum SplitTunnelMode {
  off,
  include,
  exclude;

  static SplitTunnelMode fromPerAppProxyMode(PerAppProxyMode mode) {
    switch (mode) {
      case PerAppProxyMode.off:
        return SplitTunnelMode.off;
      case PerAppProxyMode.include:
        return SplitTunnelMode.include;
      case PerAppProxyMode.exclude:
        return SplitTunnelMode.exclude;
    }
  }

  PerAppProxyMode toPerAppProxyMode() {
    switch (this) {
      case SplitTunnelMode.off:
        return PerAppProxyMode.off;
      case SplitTunnelMode.include:
        return PerAppProxyMode.include;
      case SplitTunnelMode.exclude:
        return PerAppProxyMode.exclude;
    }
  }

  bool get isEnabled => this != SplitTunnelMode.off;
}

/// Immutable split-tunnel preferences for the current platform.
class SplitTunnelSettings {
  const SplitTunnelSettings({
    this.mode = SplitTunnelMode.off,
    this.selectedPackages = const {},
  });

  final SplitTunnelMode mode;
  final Set<String> selectedPackages;

  bool get isEnabled => mode.isEnabled;

  bool isPackageSelected(String packageName) =>
      selectedPackages.contains(packageName);

  SplitTunnelSettings copyWith({
    SplitTunnelMode? mode,
    Set<String>? selectedPackages,
  }) {
    return SplitTunnelSettings(
      mode: mode ?? this.mode,
      selectedPackages: selectedPackages ?? this.selectedPackages,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SplitTunnelSettings &&
        other.mode == mode &&
        _setEquals(other.selectedPackages, selectedPackages);
  }

  @override
  int get hashCode => Object.hash(mode, Object.hashAllUnordered(selectedPackages));
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) {
    return false;
  }
  return a.containsAll(b);
}
