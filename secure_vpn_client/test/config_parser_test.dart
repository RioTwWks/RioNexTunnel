import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/credentials.dart';
import 'package:secure_vpn_client/models/socks_auth_mode.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';

void main() {
  final credentials = CredentialService().generate();

  const sampleXray = '''
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 7890,
      "protocol": "socks",
      "settings": { "auth": "noauth" }
    }
  ],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
''';

  const sampleSingbox = '''
{
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": 7890
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
''';

  group('ConfigParser', () {
    test('injects secure Xray SOCKS inbound', () {
      final result = ConfigParser.injectSecureSocksInbound(
        sampleXray,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final inbounds = decoded['inbounds'] as List<dynamic>;

      final tags = inbounds
          .whereType<Map>()
          .map((inbound) => inbound['tag'])
          .toList();
      expect(tags, containsAll(['tun-in', 'secure-socks-in']));
      final socks = inbounds.whereType<Map>().firstWhere(
        (inbound) => inbound['tag'] == 'secure-socks-in',
      );
      expect(socks['listen'], '127.0.0.1');
      expect(socks['port'], ConfigParser.defaultSocksPort);
      expect(socks['settings']['auth'], 'password');
    });

    test('injects secure sing-box SOCKS inbound', () {
      final result = ConfigParser.injectSecureSocksInbound(
        sampleSingbox,
        credentials,
        VpnEngine.singbox,
      );
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final inbounds = decoded['inbounds'] as List<dynamic>;

      expect(inbounds.length, 1);
      final inbound = inbounds.first as Map<String, dynamic>;
      expect(inbound['listen'], '127.0.0.1');
      expect(inbound['listen_port'], ConfigParser.defaultSocksPort);
      expect((inbound['users'] as List).isNotEmpty, isTrue);
    });

    test('VPN mode keeps tun inbound for xray (not proxyOnly)', () {
      const withTun = '''
{
  "inbounds": [
    {"tag": "tun", "protocol": "tun", "port": 0, "settings": {"name": "xray0"}},
    {"tag": "socks", "protocol": "socks", "listen": "127.0.0.1", "port": 10808,
     "settings": {"auth": "noauth"}}
  ],
  "outbounds": [{"protocol": "vless", "tag": "proxy"}]
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        withTun,
        credentials,
        VpnEngine.xray,
      );
      final tags = (jsonDecode(result) as Map)['inbounds'] as List;
      final protocols = tags
          .whereType<Map>()
          .map((inbound) => inbound['protocol'])
          .toList();
      expect(protocols, contains('tun'));
      expect(protocols, contains('socks'));
    });

    test('validateSecure rejects missing auth', () {
      const unsafe = '''
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 1080,
      "protocol": "socks",
      "settings": { "auth": "noauth" }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      expect(
        () => ConfigParser.validateSecure(unsafe, engine: VpnEngine.xray),
        throwsA(isA<ConfigParserException>()),
      );
    });

    test('proxyOnly strips all existing inbounds from subscription JSON', () {
      const subscriptionLike = '''
{
  "inbounds": [
    {"tag": "tun-in", "type": "tun"},
    {"tag": "mixed-in", "type": "mixed", "listen": "127.0.0.1", "listen_port": 2334}
  ],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        subscriptionLike,
        credentials,
        VpnEngine.singbox,
        proxyOnly: true,
      );
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final tags = (decoded['inbounds'] as List)
          .whereType<Map>()
          .map((inbound) => inbound['tag'])
          .toList();
      expect(tags, ['secure-socks-in', 'secure-http-in']);
    });

    test('detects xray geosite/geoip rule requirements', () {
      expect(
        ConfigParser.configRequiresXrayGeoRules(
          '{"routing":{"rules":[{"domain":["geosite:cn"]}]}}',
        ),
        isTrue,
      );
      expect(
        ConfigParser.configRequiresXrayGeoRules('{"outbounds":[]}'),
        isFalse,
      );
    });

    test('strips deprecated allowInsecure from xray TLS settings', () {
      const withInsecure = '''
{
  "outbounds": [{
    "protocol": "vmess",
    "tag": "proxy",
    "streamSettings": {
      "security": "tls",
      "tlsSettings": {"serverName": "example.com", "allowInsecure": true}
    }
  }],
  "inbounds": []
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        withInsecure,
        credentials,
        VpnEngine.xray,
      );
      expect(result.contains('allowInsecure'), isFalse);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final outbound = (decoded['outbounds'] as List).first as Map;
      final tls =
          ((outbound['streamSettings'] as Map)['tlsSettings'] as Map);
      expect(tls.containsKey('allowInsecure'), isFalse);
      expect(tls['serverName'], 'example.com');
    });

    test('normalizes v2rayNG JSON array subscriptions', () {
      const body = '''
[
  {
    "remarks": "decoy",
    "outbounds": [{"protocol": "freedom", "tag": "direct"}]
  },
  {
    "remarks": "server-1",
    "inbounds": [{"tag": "socks", "protocol": "socks", "listen": "127.0.0.1", "port": 10808}],
    "outbounds": [{"protocol": "vless", "tag": "proxy-node"}]
  }
]
''';
      final normalized = ConfigParser.normalizeSubscriptionContent(body);
      final decoded = jsonDecode(normalized) as Map<String, dynamic>;
      expect(decoded['remarks'], 'server-1');
    });

    test('lists and selects v2rayNG servers by index', () {
      const body = '''
[
  {
    "remarks": "decoy",
    "outbounds": [{"protocol": "freedom", "tag": "direct"}]
  },
  {
    "remarks": "Frankfurt",
    "outbounds": [{"protocol": "vless", "tag": "proxy-a"}]
  },
  {
    "remarks": "Amsterdam",
    "outbounds": [{"protocol": "vmess", "tag": "proxy-b"}]
  }
]
''';
      final servers = ConfigParser.listSubscriptionServers(body);
      expect(servers.length, 2);
      expect(servers[0].name, 'Frankfurt');
      expect(servers[1].name, 'Amsterdam');
      expect(servers[0].index, 0);
      expect(servers[1].index, 1);

      final second = ConfigParser.normalizeSubscriptionContent(
        body,
        serverIndex: 1,
      );
      expect(jsonDecode(second)['remarks'], 'Amsterdam');
    });

    test('lists link-based subscription servers with fragment names', () {
      const body = '''
#No Time Limit
trojan://1@20.07--2026.06.09.time:2007?sni=fake_ip_for_sub_link&security=tls
vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls#Node%20A
trojan://secret@node.example:8443?security=tls#Node%20B
''';
      final servers = ConfigParser.listSubscriptionServers(body);
      expect(servers.length, 2);
      expect(servers[0].name, 'Node A');
      expect(servers[1].name, 'Node B');

      final selected = ConfigParser.normalizeSubscriptionContent(
        body,
        serverIndex: 1,
      );
      expect(selected.startsWith('trojan://'), isTrue);
      expect(selected.contains('node.example'), isTrue);
    });

    test('rejects out-of-range server index', () {
      const body = '''
[
  {
    "remarks": "only",
    "outbounds": [{"protocol": "vless", "tag": "proxy"}]
  }
]
''';
      expect(
        () => ConfigParser.normalizeSubscriptionContent(body, serverIndex: 3),
        throwsA(isA<ConfigParserException>()),
      );
    });

    test('rewrites placeholder proxy routing tag for xray subscriptions', () {
      const subscription = '''
{
  "outbounds": [{"protocol": "vless", "tag": "node-1"}],
  "routing": {
    "rules": [
      {"type": "field", "inboundTag": ["api"], "outboundTag": "api"},
      {"type": "field", "port": "0-65535", "outboundTag": "proxy"}
    ]
  }
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        subscription,
        credentials,
        VpnEngine.xray,
      );
      final rules =
          ((jsonDecode(result) as Map)['routing'] as Map)['rules']
              as List<dynamic>;
      expect(rules.length, 1);
      expect((rules.first as Map)['outboundTag'], 'node-1');
    });

    test('migrates sing-box legacy DNS servers', () {
      const legacy = '''
{
  "dns": {
    "servers": [
      {"address": "8.8.8.8", "tag": "dns-local"},
      {"address": "tcp://1.1.1.1", "tag": "dns-remote"}
    ]
  },
  "inbounds": [],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        legacy,
        credentials,
        VpnEngine.singbox,
      );
      final servers =
          ((jsonDecode(result) as Map)['dns'] as Map)['servers']
              as List<dynamic>;
      expect(servers.first['type'], 'udp');
      expect(servers.first['server'], '8.8.8.8');
      expect(servers[1]['type'], 'tcp');
    });

    test('skips decoy subscription links', () {
      const body = '''
#No Time Limit
trojan://1@20.07--2026.06.09.time:2007?sni=fake_ip_for_sub_link&security=tls
vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls
''';
      final normalized = ConfigParser.normalizeSubscriptionContent(body);
      expect(normalized.startsWith('vless://'), isTrue);
    });

    test('removes invalid dns-in inbound without port', () {
      const brokenDns = '''
{
  "inbounds": [
    {
      "tag": "dns-in",
      "listen": "127.0.0.1",
      "protocol": "dokodemo-door",
      "settings": { "address": "1.1.1.1", "port": 53, "network": "tcp,udp" }
    }
  ],
  "routing": {
    "rules": [
      { "type": "field", "inboundTag": ["dns-in"], "outboundTag": "dns-out" }
    ]
  },
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
''';
      final result = ConfigParser.injectSecureSocksInbound(
        brokenDns,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final tags = (decoded['inbounds'] as List)
          .whereType<Map>()
          .map((inbound) => inbound['tag'])
          .toList();
      expect(tags, contains('secure-socks-in'));
      expect(tags, isNot(contains('dns-in')));
      final rules = (decoded['routing'] as Map)['rules'] as List;
      expect(rules, isEmpty);
    });

    test('validateSecure rejects 0.0.0.0 bind', () {
      final injected = ConfigParser.injectSecureSocksInbound(
        sampleXray,
        credentials,
        VpnEngine.xray,
      );
      expect(
        () => ConfigParser.validateSecure(injected, engine: VpnEngine.xray),
        returnsNormally,
      );
    });


    test('extractPanelSocksAuth reads xray inbound and local_proxy shortcut', () {
      const xrayConfig = '{"inbounds":[{"protocol":"socks","listen":"127.0.0.1","port":2080,"settings":{"auth":"password","accounts":[{"user":"panel-user","pass":"panel-pass"}]}}],"outbounds":[]}';
      final fromInbound = ConfigParser.extractPanelSocksAuth(jsonDecode(xrayConfig) as Map<String, dynamic>, engine: VpnEngine.xray);
      expect(fromInbound?.username, 'panel-user');
      expect(fromInbound?.port, 2080);
      final fromShortcut = ConfigParser.extractPanelSocksAuth({'local_proxy': {'port': 1090, 'username': 'shortcut-user', 'password': 'shortcut-pass'}}, engine: VpnEngine.singbox);
      expect(fromShortcut?.username, 'shortcut-user');
    });

    test('staticFromPanel uses panel port and credentials', () {
      const config = '{"inbounds":[],"outbounds":[{"protocol":"freedom","tag":"direct"}]}';
      final panelSocks = ConfigParser.extractPanelSocksAuth({'local_proxy': {'port': 2080, 'username': 'static-user', 'password': 'static-pass'}}, engine: VpnEngine.xray);
      final credentials = SessionCredentials(username: panelSocks!.username, password: panelSocks.password);
      final result = ConfigParser.injectSecureSocksInbound(config, credentials, VpnEngine.xray, authMode: SocksAuthMode.staticFromPanel, panelSocks: panelSocks);
      final socks = (jsonDecode(result) as Map)['inbounds'].whereType<Map>().firstWhere((inbound) => inbound['tag'] == 'secure-socks-in');
      expect(socks['port'], 2080);
    });

    test('disableInjection keeps existing authenticated socks inbound', () {
      const config = '{"inbounds":[{"tag":"custom-socks","protocol":"socks","listen":"127.0.0.1","port":1080,"settings":{"auth":"password","accounts":[{"user":"cfg-user","pass":"cfg-pass"}]}}],"outbounds":[{"protocol":"freedom","tag":"direct"}]}';
      final credentials = SessionCredentials(username: 'cfg-user', password: 'cfg-pass');
      final result = ConfigParser.injectSecureSocksInbound(config, credentials, VpnEngine.xray, authMode: SocksAuthMode.disableInjection);
      final inbounds = (jsonDecode(result) as Map)['inbounds'] as List;
      expect(inbounds.length, 1);
      expect(inbounds.first['tag'], 'custom-socks');
    });
  });
}
