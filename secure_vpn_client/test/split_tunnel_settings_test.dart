import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/split_tunnel_settings.dart';

void main() {
  group('SplitTunnelMode', () {
    test('isEnabled is false only for off', () {
      expect(SplitTunnelMode.off.isEnabled, isFalse);
      expect(SplitTunnelMode.include.isEnabled, isTrue);
      expect(SplitTunnelMode.exclude.isEnabled, isTrue);
    });
  });

  group('SplitTunnelSettings', () {
    test('copyWith preserves unspecified fields', () {
      const initial = SplitTunnelSettings(
        mode: SplitTunnelMode.include,
        selectedPackages: {'com.example.vpn'},
      );

      final updated = initial.copyWith(
        selectedPackages: {'com.example.vpn', 'com.example.browser'},
      );

      expect(updated.mode, SplitTunnelMode.include);
      expect(updated.selectedPackages, {
        'com.example.vpn',
        'com.example.browser',
      });
    });

    test('isPackageSelected reflects selectedPackages', () {
      const settings = SplitTunnelSettings(
        mode: SplitTunnelMode.exclude,
        selectedPackages: {'com.example.banking'},
      );

      expect(settings.isPackageSelected('com.example.banking'), isTrue);
      expect(settings.isPackageSelected('com.example.other'), isFalse);
    });

    test('equality compares mode and packages', () {
      const a = SplitTunnelSettings(
        mode: SplitTunnelMode.exclude,
        selectedPackages: {'com.a'},
      );
      const b = SplitTunnelSettings(
        mode: SplitTunnelMode.exclude,
        selectedPackages: {'com.a'},
      );
      const c = SplitTunnelSettings(
        mode: SplitTunnelMode.include,
        selectedPackages: {'com.a'},
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
