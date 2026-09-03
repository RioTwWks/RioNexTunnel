import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/credentials.dart';
import 'package:secure_vpn_client/models/panel_socks_inbound.dart';
import 'package:secure_vpn_client/models/socks_auth_mode.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';

void main() {
  group('Security', () {
    test('credentials are not exposed in toString', () {
      final service = CredentialService();
      final credentials = service.generate();
      expect(credentials.toString(), isNot(contains(credentials.username)));
      expect(credentials.toString(), isNot(contains(credentials.password)));
    });

    test('parser removes vulnerable port 7890 inbounds', () {
      const config = '''
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 7890,
      "protocol": "socks",
      "settings": { "auth": "noauth" }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      final credentials = CredentialService().generate();
      final secure = ConfigParser.injectSecureSocksInbound(
        config,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(secure) as Map<String, dynamic>;
      final ports = (decoded['inbounds'] as List)
          .map((item) => (item as Map)['port'])
          .toList();
      expect(ports, isNot(contains(ConfigParser.vulnerablePort)));
    });

    test('secure config always binds localhost', () {
      const config = '''
{
  "inbounds": [],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      final credentials = CredentialService().generate();
      final secure = ConfigParser.injectSecureSocksInbound(
        config,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(secure) as Map<String, dynamic>;
      for (final inbound in decoded['inbounds'] as List) {
        final map = inbound as Map;
        if (map['protocol'] == 'tun') {
          continue;
        }
        expect(map['listen'], '127.0.0.1');
      }
      expect(
        (decoded['inbounds'] as List).any(
          (inbound) => (inbound as Map)['protocol'] == 'tun',
        ),
        isTrue,
      );
    });

    test('proxyOnly config stays secure regardless of split tunnel state', () {
      const config = '''
{
  "inbounds": [],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      final credentials = CredentialService().generate();
      for (final engine in VpnEngine.values) {
        final secure = ConfigParser.injectSecureSocksInbound(
          config,
          credentials,
          engine,
          proxyOnly: true,
        );
        final decoded = jsonDecode(secure) as Map<String, dynamic>;
        for (final inbound in decoded['inbounds'] as List) {
          final map = inbound as Map;
          expect(map['listen'], '127.0.0.1');
        }
        expect(
          (decoded['inbounds'] as List).any(
            (inbound) =>
                (inbound as Map)['port'] == ConfigParser.vulnerablePort,
          ),
          isFalse,
        );
      }
    });


    test('staticFromPanel still binds localhost with auth', () {
      const config = '{"inbounds":[],"outbounds":[{"protocol":"freedom"}]}';
      final credentials = SessionCredentials(username: 'panel-static', password: 'panel-secret');
      final secure = ConfigParser.injectSecureSocksInbound(config, credentials, VpnEngine.xray, authMode: SocksAuthMode.staticFromPanel, panelSocks: const PanelSocksInbound(username: 'panel-static', password: 'panel-secret', port: 2080));
      final socks = (jsonDecode(secure) as Map)['inbounds'].cast<Map>().firstWhere((inbound) => inbound['tag'] == 'secure-socks-in');
      expect(socks['listen'], '127.0.0.1');
      expect(socks['port'], 2080);
    });

    test('disableInjection rejects unauthenticated socks', () {
      const config = '{"inbounds":[{"protocol":"socks","listen":"127.0.0.1","port":1080,"settings":{"auth":"noauth"}}],"outbounds":[{"protocol":"freedom"}]}';
      final credentials = CredentialService().generate();
      expect(() => ConfigParser.injectSecureSocksInbound(config, credentials, VpnEngine.xray, authMode: SocksAuthMode.disableInjection), throwsA(isA<ConfigParserException>()));
    });
  });
}
