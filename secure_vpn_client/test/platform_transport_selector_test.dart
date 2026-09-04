import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/subscription_server.dart';
import 'package:secure_vpn_client/utils/platform_transport_selector.dart';
import 'package:secure_vpn_client/utils/server_latency.dart';

SubscriptionServer _server(int index, String content) {
  return SubscriptionServer(index: index, name: 's$index', content: content);
}

void main() {
  group('PlatformTransportSelector', () {
    const xhttp =
        'vless://11111111-2222-3333-4444-555555555555@a.example.com:443'
        '?security=reality&type=xhttp&mode=stream-one&pbk=abc&sni=cdn.example.com';
    const vision =
        'vless://11111111-2222-3333-4444-555555555555@b.example.com:443'
        '?security=reality&type=tcp&flow=xtls-rprx-vision&pbk=abc&sni=cdn.example.com';

    test('classifies XHTTP and Vision stacks', () {
      expect(
        PlatformTransportSelector.classifyStack(xhttp),
        CensorshipTransportStack.xhttpReality,
      );
      expect(
        PlatformTransportSelector.classifyStack(vision),
        CensorshipTransportStack.tcpRealityVision,
      );
    });

    test('non-iOS prefers XHTTP stack over Vision despite latency', () {
      final best = PlatformTransportSelector.selectBest(
        [
          ServerLatencyResult(server: _server(0, vision), latencyMs: 30),
          ServerLatencyResult(server: _server(1, xhttp), latencyMs: 80),
        ],
        ios: false,
      );
      expect(best?.server.index, 1);
    });

    test('iOS prefers Vision even when XHTTP has lower latency', () {
      final best = PlatformTransportSelector.selectBest(
        [
          ServerLatencyResult(server: _server(0, xhttp), latencyMs: 20),
          ServerLatencyResult(server: _server(1, vision), latencyMs: 90),
        ],
        ios: true,
      );
      expect(best?.server.index, 1);
    });
  });
}
