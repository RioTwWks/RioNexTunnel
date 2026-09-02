import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/split_tunnel_settings.dart';
import 'package:secure_vpn_client/providers/per_app_proxy_provider.dart';

void main() {
  group('PerAppProxySettings', () {
    test('excludeEnabled is true only in exclude mode', () {
      expect(
        const PerAppProxySettings(mode: SplitTunnelMode.exclude).excludeEnabled,
        isTrue,
      );
      expect(
        const PerAppProxySettings(mode: SplitTunnelMode.off).excludeEnabled,
        isFalse,
      );
      expect(
        const PerAppProxySettings(mode: SplitTunnelMode.include).excludeEnabled,
        isFalse,
      );
    });

    test('includedPackages and excludedPackages reflect mode', () {
      const settings = PerAppProxySettings(
        mode: SplitTunnelMode.include,
        selectedPackages: {'com.example.vpn'},
        loading: false,
      );

      expect(settings.includedPackages, {'com.example.vpn'});
      expect(settings.excludedPackages, isEmpty);
    });

    test('copyWith preserves unspecified fields', () {
      const initial = PerAppProxySettings(
        mode: SplitTunnelMode.exclude,
        selectedPackages: {'com.example.app'},
        loading: false,
      );

      final updated = initial.copyWith(
        selectedPackages: {'com.example.app', 'com.example.banking'},
      );

      expect(updated.mode, SplitTunnelMode.exclude);
      expect(updated.loading, isFalse);
      expect(updated.selectedPackages, {
        'com.example.app',
        'com.example.banking',
      });
    });

    test('loaded state must clear loading flag', () {
      const loaded = PerAppProxySettings(
        mode: SplitTunnelMode.off,
        loading: false,
      );
      expect(loaded.loading, isFalse);
    });

    test('toSettings round-trips mode and packages', () {
      const settings = PerAppProxySettings(
        mode: SplitTunnelMode.include,
        selectedPackages: {'com.example.a'},
        loading: false,
      );

      final tunnel = settings.toSettings();
      expect(tunnel.mode, SplitTunnelMode.include);
      expect(tunnel.selectedPackages, {'com.example.a'});
    });
  });
}
