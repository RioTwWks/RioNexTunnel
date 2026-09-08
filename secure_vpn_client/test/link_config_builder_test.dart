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
      const link =
          'trojan://secret@example.com:443?security=tls&sni=example.com';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>;
      expect(outbounds.first['type'], 'trojan');
      final dnsServers = (decoded['dns'] as Map)['servers'] as List;
      expect(dnsServers.every((s) => (s as Map)['type'] != 'local'), isTrue);
      expect(
        ((decoded['route'] as Map)['default_domain_resolver'] as Map)['server'],
        'dns-direct',
      );
    });

    test('recognizes hysteria2 / tuic / wireguard / ssh links', () {
      expect(
        LinkConfigBuilder.isConfigLink('hy2://pw@h.example:443?sni=h.example'),
        isTrue,
      );
      expect(
        LinkConfigBuilder.isConfigLink('hysteria2://pw@h.example:443'),
        isTrue,
      );
      expect(
        LinkConfigBuilder.isConfigLink('tuic://uuid:pass@t.example:443'),
        isTrue,
      );
      expect(
        LinkConfigBuilder.isConfigLink('wg://key@w.example:51820'),
        isTrue,
      );
      expect(
        LinkConfigBuilder.isConfigLink(
          'awg://key@w.example:51820?publickey=PUB&jc=4',
        ),
        isTrue,
      );
      expect(
        LinkConfigBuilder.isConfigLink('ssh://user:pass@s.example:22'),
        isTrue,
      );
      expect(
        LinkConfigBuilder.requiresSingbox('hy2://pw@h.example:443'),
        isTrue,
      );
      expect(LinkConfigBuilder.requiresSingbox('vless://u@h:443'), isFalse);
    });

    test('builds sing-box config from hysteria2 link', () {
      const link =
          'hy2://secret@hy2.example:443?sni=hy2.example&obfs=salamander&obfs-password=obfs#Node';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbound =
          (decoded['outbounds'] as List).first as Map<String, dynamic>;
      expect(outbound['type'], 'hysteria2');
      expect(outbound['server'], 'hy2.example');
      expect(outbound['password'], 'secret');
      expect((outbound['tls'] as Map)['server_name'], 'hy2.example');
      expect((outbound['obfs'] as Map)['type'], 'salamander');
    });

    test('builds sing-box config from tuic link', () {
      const link =
          'tuic://11111111-2222-3333-4444-555555555555:pass@tuic.example:443?sni=tuic.example&congestion_control=bbr';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['type'], 'tuic');
      expect(outbound['uuid'], '11111111-2222-3333-4444-555555555555');
      expect(outbound['congestion_control'], 'bbr');
    });

    test('builds sing-box config from wireguard link', () {
      const link =
          'wg://PRIVATE@wg.example:51820?publickey=PUB&address=10.0.0.2/32&mtu=1280';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['type'], 'wireguard');
      expect(outbound['peer_public_key'], 'PUB');
      expect(outbound['local_address'], ['10.0.0.2/32']);
      expect(outbound['mtu'], 1280);
    });

    test('builds sing-box config from ssh link', () {
      const link = 'ssh://alice:secret@ssh.example:22';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['type'], 'ssh');
      expect(outbound['user'], 'alice');
      expect(outbound['password'], 'secret');
      expect(outbound['server_port'], 22);
    });

    test('rejects sing-box-only protocols on xray engine', () {
      expect(
        () => LinkConfigBuilder.buildFromLink(
          'hy2://pw@hy2.example:443',
          VpnEngine.xray,
        ),
        throwsA(isA<ConfigParserException>()),
      );
    });
  });

  group('ConfigParser subscription', () {
    test('extracts first config link from base64 subscription', () {
      const body = 'dmxlc3M6Ly9hYmNkQGV4YW1wbGUuY29tOjQ0Mw==';
      final normalized = ConfigParser.normalizeSubscriptionContent(body);
      expect(normalized.startsWith('vless://'), isTrue);
    });

    test('lists hysteria2 links from subscription body', () {
      const body = '''
hy2://secret@hy2.example:443?sni=hy2.example#HY2
vless://11111111-2222-3333-4444-555555555555@vless.example:443?security=tls#VLESS
''';
      final servers = ConfigParser.listSubscriptionServers(body);
      expect(servers.length, 2);
      expect(servers.first.content.startsWith('hy2://'), isTrue);
      expect(servers.first.name, 'HY2');
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
      expect(servers.every((s) => (s as Map)['type'] != 'local'), isTrue);
      expect(servers.every((s) => (s as Map)['detour'] != 'direct'), isTrue);
      expect(
        (((jsonDecode(result) as Map)['experimental'] as Map)['clash_api']
            as Map)['external_controller'],
        '127.0.0.1:9090',
      );
    });
  });
}
