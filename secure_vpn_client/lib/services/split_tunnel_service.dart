import 'package:v2ray_box/v2ray_box.dart';

import '../models/split_tunnel_settings.dart';

/// Coordinates per-app split tunneling with the v2ray_box plugin.
///
/// Keeps [VpnService] free of split-tunnel details — settings are applied
/// natively on connect via persisted plugin preferences.
class SplitTunnelService {
  SplitTunnelService(this._v2rayBox);

  final V2rayBox _v2rayBox;

  Future<SplitTunnelSettings> load() async {
    final mode = SplitTunnelMode.fromPerAppProxyMode(
      await _v2rayBox.getPerAppProxyMode(),
    );
    var packages = <String>{};
    if (mode.isEnabled) {
      packages = (await _v2rayBox.getPerAppProxyList(mode.toPerAppProxyMode()))
          .toSet();
    }
    return SplitTunnelSettings(mode: mode, selectedPackages: packages);
  }

  Future<void> setMode(SplitTunnelMode mode) async {
    await _v2rayBox.setPerAppProxyMode(mode.toPerAppProxyMode());
    if (!mode.isEnabled) {
      return;
    }
    final current = await load();
    if (current.selectedPackages.isNotEmpty) {
      await _v2rayBox.setPerAppProxyList(
        current.selectedPackages.toList(),
        mode.toPerAppProxyMode(),
      );
    }
  }

  Future<void> setSelectedPackages(
    Set<String> packages,
    SplitTunnelMode mode,
  ) async {
    final effectiveMode =
        mode.isEnabled ? mode : SplitTunnelMode.exclude;
    await _v2rayBox.setPerAppProxyMode(effectiveMode.toPerAppProxyMode());
    await _v2rayBox.setPerAppProxyList(
      packages.toList(),
      effectiveMode.toPerAppProxyMode(),
    );
  }
}
