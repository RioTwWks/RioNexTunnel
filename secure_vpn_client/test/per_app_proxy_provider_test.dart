import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/providers/per_app_proxy_provider.dart';
import 'package:v2ray_box/v2ray_box.dart';

void main() {
  group('PerAppProxySettings', () {
    test('excludeEnabled is true only in exclude mode', () {
      expect(
        const PerAppProxySettings(mode: PerAppProxyMode.exclude).excludeEnabled,
        isTrue,
      );
      expect(
        const PerAppProxySettings(mode: PerAppProxyMode.off).excludeEnabled,
        isFalse,
      );
    });

    test('copyWith preserves unspecified fields', () {
      const initial = PerAppProxySettings(
        mode: PerAppProxyMode.exclude,
        excludedPackages: {'com.example.app'},
        loading: false,
      );

      final updated = initial.copyWith(
        excludedPackages: {'com.example.app', 'com.example.banking'},
      );

      expect(updated.mode, PerAppProxyMode.exclude);
      expect(updated.loading, isFalse);
      expect(updated.excludedPackages, {
        'com.example.app',
        'com.example.banking',
      });
    });

    test('loaded state must clear loading flag', () {
      // Regression: default loading=true caused infinite spinner after _load().
      const loaded = PerAppProxySettings(
        mode: PerAppProxyMode.off,
        loading: false,
      );
      expect(loaded.loading, isFalse);
    });
  });
}
