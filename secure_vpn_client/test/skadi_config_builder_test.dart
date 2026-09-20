import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/engine_preference.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/skadi_config_builder.dart';

void main() {
  group('VpnEngine.skadi', () {
    test('parses core names', () {
      expect(VpnEngine.fromCoreName('skadi'), VpnEngine.skadi);
      expect(VpnEngine.fromCoreName('skadicore'), VpnEngine.skadi);
      expect(VpnEngine.skadi.coreName, 'skadi');
      expect(VpnEngine.skadi.displayName, 'SkadiCore');
    });
  });

  group('EnginePreference.skadi', () {
    test('round-trips storage', () {
      expect(EnginePreference.fromStorage('skadi'), EnginePreference.skadi);
      expect(EnginePreference.skadi.storageName, 'skadi');
    });
  });

  group('SkadiConfigBuilder', () {
    const vlessTls =
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
        '?encryption=none&security=tls&sni=example.com&type=tcp#tls';

    const vlessReality =
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443'
        '?encryption=none&security=reality&sni=www.microsoft.com'
        '&fp=chrome&pbk=PUBLICKEY123&sid=0123456789abcdef&type=tcp#r';

    const vlessXhttp =
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443'
        '?encryption=none&security=reality&sni=www.microsoft.com'
        '&pbk=PUBLICKEY123&sid=abcd&type=xhttp&path=%2Fxhttp&mode=stream-one#x';

    test('supports VLESS links only', () {
      expect(SkadiConfigBuilder.supportsContent(vlessTls), isTrue);
      expect(
        SkadiConfigBuilder.supportsContent('trojan://pw@host:443'),
        isFalse,
      );
      expect(
        SkadiConfigBuilder.supportsContent('hy2://pw@host:443'),
        isFalse,
      );
    });

    test('builds TLS client TOML bound to loopback backend port', () {
      final toml = SkadiConfigBuilder.build(vlessTls, publicSocksPort: 1080);
      expect(toml, contains('[client]'));
      expect(toml, contains('listen = "127.0.0.1:1280"'));
      expect(toml, contains('[remote]'));
      expect(toml, contains('server = "example.com:443"'));
      expect(toml, contains('uuid = "b831381d-6324-4d53-ad4f-8cda48b30811"'));
      expect(toml, contains('[remote.tls]'));
      expect(toml, contains('enabled = true'));
      expect(toml, contains('server_name = "example.com"'));
      expect(toml, isNot(contains('0.0.0.0')));
    });

    test('builds REALITY client TOML', () {
      final toml = SkadiConfigBuilder.build(vlessReality);
      expect(toml, contains('[remote.reality]'));
      expect(toml, contains('enabled = true'));
      expect(toml, contains('password = "PUBLICKEY123"'));
      expect(toml, contains('short_id = "0123456789abcdef"'));
      expect(toml, contains('server_name = "www.microsoft.com"'));
      expect(toml, contains('[remote.tls]'));
      expect(toml, contains('enabled = false'));
    });

    test('builds XHTTP section', () {
      final toml = SkadiConfigBuilder.build(vlessXhttp);
      expect(toml, contains('[remote.xhttp]'));
      expect(toml, contains('enabled = true'));
      expect(toml, contains('path = "/xhttp"'));
      expect(toml, contains('mode = "stream-one"'));
    });

    test('rejects non-VLESS protocols', () {
      expect(
        () => SkadiConfigBuilder.build('trojan://secret@host:443?security=tls'),
        throwsA(isA<Exception>()),
      );
    });

    test('internal port offset is stable', () {
      expect(SkadiConfigBuilder.internalSocksPort(1080), 1280);
      expect(SkadiConfigBuilder.internalPortOffset, 200);
    });
  });
}
