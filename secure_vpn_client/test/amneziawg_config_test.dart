import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/amnezia_wg_config.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';

void main() {
  group('AmneziaWgConfig', () {
    test('detects AWG from awg:// scheme', () {
      const link =
          'awg://CLIENT@vpn.example:51820?publickey=SERVER&address=10.8.1.2/32&jc=4';
      expect(AmneziaWgConfig.contentUsesAwg(link), isTrue);
      expect(LinkConfigBuilder.isConfigLink(link), isTrue);
    });
  });

  group('LinkConfigBuilder AmneziaWG', () {
    const link =
        'awg://CLIENT@vpn.example:51820?publickey=SERVER&address=10.8.1.2/32&jc=4&jmin=40&jmax=70';

    test('builds sing-box outbound with AWG fields', () {
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['jc'], 4);
      expect(outbound['mtu'], 1280);
    });

    test('fixture link round-trips', () {
      final fixture = File('test/fixtures/amneziawg_link_sample.txt')
          .readAsStringSync()
          .trim();
      final json = LinkConfigBuilder.buildFromLink(fixture, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['jc'], 4);
    });

    test('secure SOCKS injection preserves AWG outbound', () {
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final secure = ConfigParser.injectSecureSocksInbound(
        json,
        CredentialService().generate(),
        VpnEngine.singbox,
        proxyOnly: true,
      );
      final outbound = (jsonDecode(secure) as Map)['outbounds']
          .cast<Map>()
          .firstWhere((o) => o['type'] == 'wireguard');
      expect(outbound['jc'], 4);
    });
  });
}
