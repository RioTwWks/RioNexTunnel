import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';

void main() {
  group('LinkConfigBuilder', () {
    test('builds Xray config from vless link', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls&sni=example.com&type=ws&path=/ws#test';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>;
      expect(outbounds.first['protocol'], 'vless');
    });

    test('builds sing-box config from trojan link', () {
      const link = 'trojan://secret@example.com:443?security=tls&sni=example.com';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>;
      expect(outbounds.first['type'], 'trojan');
      final dnsServers = (decoded['dns'] as Map)['servers'] as List;
      expect(
        dnsServers.every((s) => (s as Map)['type'] != 'local'),
        isTrue,
      );
      expect(
        ((decoded['route'] as Map)['default_domain_resolver'] as Map)['server'],
        'dns-direct',
      );
    });
  });

  group('ConfigParser subscription', () {
    test('extracts first config link from base64 subscription', () {
      const body = 'dmxlc3M6Ly9hYmNkQGV4YW1wbGUuY29tOjQ0Mw==';
      final normalized = ConfigParser.normalizeSubscriptionContent(body);
      expect(normalized.startsWith('vless://'), isTrue);
    });

    test('replaces sing-box local DNS for VPN-safe resolvers', () {
      const withLocal = '''
{
  "dns": {"servers": [{"type": "local", "tag": "dns-direct"}]},
  "inbounds": [],
  "outbounds": [{"type": "direct", "tag": "direct"}],
  "route": {"final": "direct"}
}
''';
      final credentials = CredentialService().generate();
      final result = ConfigParser.injectSecureSocksInbound(
        withLocal,
        credentials,
        VpnEngine.singbox,
      );
      final dns = (jsonDecode(result) as Map)['dns'] as Map;
      final servers = dns['servers'] as List;
      expect(servers, isNotEmpty);
      expect(
        servers.every((s) => (s as Map)['type'] != 'local'),
        isTrue,
      );
      expect(
        servers.every((s) => (s as Map)['detour'] != 'direct'),
        isTrue,
      );
      expect(
        (((jsonDecode(result) as Map)['experimental'] as Map)['clash_api']
            as Map)['external_controller'],
        '127.0.0.1:9090',
      );
    });
  });
}
