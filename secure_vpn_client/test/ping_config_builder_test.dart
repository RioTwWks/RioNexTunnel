import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/ping_config_builder.dart';

void main() {
  const sampleVless =
      'vless://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee@node.example.com:443'
      '?encryption=none&security=tls&sni=node.example.com&type=tcp';

  group('PingConfigBuilder', () {
    test('resolveEngine picks sing-box for hysteria links', () {
      expect(
        PingConfigBuilder.resolveEngine(
          'hy2://token@node.example.com:443',
          VpnEngine.xray,
        ),
        VpnEngine.singbox,
      );
    });

    test('build creates xray measure config with socks inbound', () async {
      final measure = await PingConfigBuilder.build(sampleVless, VpnEngine.xray);
      expect(measure.engine, VpnEngine.xray);
      expect(measure.socksPort, greaterThan(0));

      final config = jsonDecode(measure.configJson) as Map<String, dynamic>;
      final inbounds = config['inbounds'] as List<dynamic>;
      expect(inbounds.length, 1);
      final inbound = inbounds.first as Map<String, dynamic>;
      expect(inbound['protocol'], 'socks');
      expect(inbound['listen'], '127.0.0.1');
      expect(inbound['port'], measure.socksPort);

      final outbounds = config['outbounds'] as List<dynamic>;
      expect(outbounds.first['tag'], 'proxy');
      expect(outbounds.first['protocol'], 'vless');
    });

    test('build creates sing-box measure config for sing-box-only link', () async {
      final measure = await PingConfigBuilder.build(
        'hy2://token@node.example.com:443',
        VpnEngine.xray,
      );
      expect(measure.engine, VpnEngine.singbox);

      final config = jsonDecode(measure.configJson) as Map<String, dynamic>;
      final inbound = (config['inbounds'] as List).first as Map<String, dynamic>;
      expect(inbound['type'], 'mixed');
      expect(inbound['listen_port'], measure.socksPort);
    });

    test('strips xray mux from subscription JSON for fair latency probe', () async {
      const configWithMux = '''
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "node.example.com",
            "port": 443,
            "users": [{"id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}]
          }
        ]
      },
      "mux": {"enabled": true, "concurrency": 8}
    }
  ]
}
''';
      final measure = await PingConfigBuilder.build(
        configWithMux,
        VpnEngine.xray,
      );
      final config = jsonDecode(measure.configJson) as Map<String, dynamic>;
      final outbound =
          (config['outbounds'] as List).first as Map<String, dynamic>;
      expect(outbound.containsKey('mux'), isFalse);
      expect(outbound['protocol'], 'vless');
    });

    test('strips sing-box multiplex from subscription JSON for latency probe',
        () async {
      const configWithMux = '''
{
  "outbounds": [
    {
      "type": "vless",
      "server": "node.example.com",
      "server_port": 443,
      "uuid": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "multiplex": {"enabled": true, "max_connections": 8}
    }
  ]
}
''';
      final measure = await PingConfigBuilder.build(
        configWithMux,
        VpnEngine.singbox,
      );
      final config = jsonDecode(measure.configJson) as Map<String, dynamic>;
      final outbound =
          (config['outbounds'] as List).first as Map<String, dynamic>;
      expect(outbound.containsKey('multiplex'), isFalse);
      expect(outbound['type'], 'vless');
    });
  });
}
