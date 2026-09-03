import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/utils/core_version_gate.dart';

void main() {
  group('CoreVersionGate', () {
    const xhttpLink =
        'vless://11111111-2222-3333-4444-555555555555@example.com:443'
        '?security=reality&type=xhttp&mode=stream-one&pbk=abc&sni=cdn.example.com';

    test('compareSemver orders dotted versions', () {
      expect(CoreVersionGate.compareSemver('26.3.26', '26.3.27'), lessThan(0));
      expect(CoreVersionGate.compareSemver('26.3.27', '26.3.27'), 0);
    });

    test('isOlderThanPin flags stale cores', () {
      expect(CoreVersionGate.isOlderThanPin('26.2.6'), isTrue);
      expect(CoreVersionGate.isOlderThanPin('26.3.27'), isFalse);
    });

    test('xhttpCompatibilityWarning for old core', () {
      final warning = CoreVersionGate.xhttpCompatibilityWarning(
        actualVersion: '26.2.6',
        content: xhttpLink,
      );
      expect(warning, contains('fetch_cores.sh'));
    });
  });
}
