import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/subscription_server.dart';
import 'package:secure_vpn_client/utils/server_latency.dart';

void main() {
  group('ServerLatencyProbe.endpointFromContent', () {
    test('extracts host/port from vless link', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@node.example:8443?security=tls#EU';
      final endpoint = ServerLatencyProbe.endpointFromContent(link);
      expect(endpoint?.host, 'node.example');
      expect(endpoint?.port, 8443);
    });

    test('extracts host/port from vmess link', () {
      // {"v":"2","ps":"n","add":"vm.example","port":"443","id":"...","aid":"0","net":"tcp"}
      const encoded =
          'eyJ2IjoiMiIsInBzIjoibiIsImFkZCI6InZtLmV4YW1wbGUiLCJwb3J0IjoiNDQzIiwiaWQiOiIxMTExMTExMS0yMjIyLTMzMzMtNDQ0NC01NTU1NTU1NTU1NTUiLCJhaWQiOiIwIiwibmV0IjoidGNwIn0=';
      final endpoint = ServerLatencyProbe.endpointFromContent(
        'vmess://$encoded',
      );
      expect(endpoint?.host, 'vm.example');
      expect(endpoint?.port, 443);
    });

    test('extracts host/port from xray JSON outbound', () {
      const json = '''
{
  "remarks": "Frankfurt",
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [{"address": "fra.example", "port": 443}]
      }
    }
  ]
}
''';
      final endpoint = ServerLatencyProbe.endpointFromContent(json);
      expect(endpoint?.host, 'fra.example');
      expect(endpoint?.port, 443);
    });

    test('extracts host/port from hy2 link', () {
      const link = 'hy2://secret@hy2.example:8443?sni=hy2.example#Node';
      final endpoint = ServerLatencyProbe.endpointFromContent(link);
      expect(endpoint?.host, 'hy2.example');
      expect(endpoint?.port, 8443);
    });

    test('extracts host/port from wireguard link default port', () {
      const link = 'wg://PRIVATE@wg.example?publickey=PUB';
      final endpoint = ServerLatencyProbe.endpointFromContent(link);
      expect(endpoint?.host, 'wg.example');
      expect(endpoint?.port, 51820);
    });

    test('extracts host/port from hysteria2 sing-box JSON', () {
      const json = '''
{
  "outbounds": [
    {"type": "hysteria2", "server": "hy2.example", "server_port": 443}
  ]
}
''';
      final endpoint = ServerLatencyProbe.endpointFromContent(json);
      expect(endpoint?.host, 'hy2.example');
      expect(endpoint?.port, 443);
    });
  });

  group('ServerLatencyProbe.selectBest', () {
    SubscriptionServer server(int index, String name) => SubscriptionServer(
      index: index,
      name: name,
      content: 'vless://x@$name:443',
    );

    test('picks lowest positive latency', () {
      final best = ServerLatencyProbe.selectBest([
        ServerLatencyResult(server: server(0, 'a'), latencyMs: 120),
        ServerLatencyResult(server: server(1, 'b'), latencyMs: 40),
        ServerLatencyResult(server: server(2, 'c'), latencyMs: -1),
      ]);
      expect(best?.server.index, 1);
      expect(best?.latencyMs, 40);
    });

    test('breaks ties by lower index', () {
      final best = ServerLatencyProbe.selectBest([
        ServerLatencyResult(server: server(2, 'c'), latencyMs: 50),
        ServerLatencyResult(server: server(0, 'a'), latencyMs: 50),
        ServerLatencyResult(server: server(1, 'b'), latencyMs: 50),
      ]);
      expect(best?.server.index, 0);
    });

    test('returns null when all failed', () {
      final best = ServerLatencyProbe.selectBest([
        ServerLatencyResult(server: server(0, 'a'), latencyMs: -1),
        ServerLatencyResult(server: server(1, 'b'), latencyMs: -1),
      ]);
      expect(best, isNull);
    });
  });
}
