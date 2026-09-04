import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/transport_preset.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/amnezia_wg_config.dart';
import 'package:secure_vpn_client/utils/config_enhancer.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';
import 'package:secure_vpn_client/utils/transport_presets.dart';

void main() {
  group('TransportPresets', () {
    test('detects XHTTP + REALITY from vless link', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443'
          '?security=reality&type=xhttp&mode=stream-one&pbk=abc&sid=&sni=www.example.com';
      final detected = TransportPresets.detectFromContent(link);
      expect(detected.preset, TransportPresetId.xhttpReality);
      expect(detected.network, 'xhttp');
    });

    test('applyPresetToLink sets grpc and fingerprint', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443'
          '?security=tls&type=tcp';
      final updated = TransportPresets.applyPresetToLink(
        link,
        preset: TransportPresetId.grpcTls,
        fingerprint: TlsFingerprint.edge,
      );
      expect(updated, contains('type=grpc'));
      expect(updated, contains('fp=edge'));
    });
  });

  group('LinkConfigBuilder censorship transports', () {
    test('builds XHTTP stream-one xray outbound', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443'
          '?security=reality&type=xhttp&pbk=key&sid=ab&sni=cdn.example.com';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      final stream =
          ((jsonDecode(json) as Map)['outbounds'].first
                  as Map)['streamSettings']
              as Map;
      expect(stream['network'], 'xhttp');
      expect((stream['xhttpSettings'] as Map)['mode'], 'stream-one');
      expect((stream['realitySettings'] as Map)['fingerprint'], 'firefox');
    });

    test('coerces xhttp mode auto to stream-one', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443'
          '?security=tls&type=xhttp&mode=auto';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      final stream =
          ((jsonDecode(json) as Map)['outbounds'].first
                  as Map)['streamSettings']
              as Map;
      expect((stream['xhttpSettings'] as Map)['mode'], 'stream-one');
    });

    test('builds gRPC xray stream settings', () {
      const link =
          'trojan://secret@example.com:443?security=tls&type=grpc&serviceName=mygrpc';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      final stream =
          ((jsonDecode(json) as Map)['outbounds'].first
                  as Map)['streamSettings']
              as Map;
      expect(stream['network'], 'grpc');
      expect((stream['grpcSettings'] as Map)['serviceName'], 'mygrpc');
    });

    test('applies mux when enabled', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';
      final json = LinkConfigBuilder.buildFromLink(
        link,
        VpnEngine.xray,
        options: const LinkBuildOptions(muxEnabled: true),
      );
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect((outbound['mux'] as Map)['enabled'], isTrue);
    });

    test('builds AmneziaWG sing-box outbound from awg link', () {
      const link =
          'awg://CLIENT@vpn.example:51820?publickey=SERVER&address=10.8.1.2/32'
          '&jc=4&jmin=40&jmax=70';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final outbound =
          (jsonDecode(json) as Map)['outbounds'].first as Map<String, dynamic>;
      expect(outbound['type'], 'wireguard');
      expect(outbound['jc'], 4);
      expect(AmneziaWgConfig.contentUsesAwg(link), isTrue);
    });
  });

  group('ConfigEnhancer', () {
    test('merges RU direct routing', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';
      final base = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      const profile = Profile(
        id: 'p1',
        name: 'test',
        configLink: link,
        ruDirectRouting: true,
        censorshipModeEnabled: true,
      );
      final enhanced = ConfigEnhancer.applyProfileSettings(
        base,
        profile,
        VpnEngine.xray,
      );
      final rules =
          ((jsonDecode(enhanced) as Map)['routing'] as Map)['rules'] as List;
      expect(rules.first['domain'], contains('geosite:ru'));
    });

    test('secure SOCKS injection after enhancement', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';
      final base = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      const profile = Profile(
        id: 'p1',
        name: 'test',
        configLink: link,
        censorshipModeEnabled: true,
        ruDirectRouting: true,
      );
      final enhanced = ConfigEnhancer.applyProfileSettings(
        base,
        profile,
        VpnEngine.xray,
      );
      final credentials = CredentialService().generate();
      final secure = ConfigParser.injectSecureSocksInbound(
        enhanced,
        credentials,
        VpnEngine.xray,
        proxyOnly: true,
      );
      final socks = (jsonDecode(secure) as Map)['inbounds']
          .cast<Map>()
          .firstWhere((inbound) => inbound['protocol'] == 'socks');
      expect(socks['listen'], '127.0.0.1');
      expect((socks['settings'] as Map)['auth'], 'password');
    });
  });
}
