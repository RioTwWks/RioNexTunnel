import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/subscription_server.dart';
import 'package:secure_vpn_client/models/transport_stack.dart';
import 'package:secure_vpn_client/services/subscription_manager.dart';
import 'package:secure_vpn_client/services/transport_stack_store.dart';
import 'package:secure_vpn_client/utils/transport_stack_classifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uuid = '11111111-2222-3333-4444-555555555555';
  const host = 'example.com';
  const xhttpLink =
      'vless://$uuid@$host:443?security=reality&type=xhttp&mode=stream-one&pbk=abc&sid=ab&sni=cdn.$host#Node-XHTTP';
  const muxLink =
      'vless://$uuid@$host:443?security=tls&type=tcp&mux=1#Node-mux';
  const visionLink =
      'vless://$uuid@$host:443?security=reality&type=tcp&flow=xtls-rprx-vision&pbk=abc&sid=ab&sni=cdn.$host#Node-Vision';

  final servers = [
    const SubscriptionServer(index: 0, name: 'Node-XHTTP', content: xhttpLink),
    const SubscriptionServer(index: 1, name: 'Node-mux', content: muxLink),
    const SubscriptionServer(
      index: 2,
      name: 'Node-Vision',
      content: visionLink,
    ),
  ];

  group('SubscriptionManager', () {
    late SubscriptionManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = SubscriptionManager(store: TransportStackStore());
    });

    test('groups stacks and orders XHTTP → mux → Vision', () async {
      expect(manager.groupServers(servers).first.stacks, hasLength(3));
      final ordered = await manager.orderedProbeList(
        profileId: 'profile-1',
        servers: servers,
        selectedIndex: 0,
      );
      expect(ordered.map((c) => c.kind).toList(), [
        TransportStackKind.xhttpReality,
        TransportStackKind.tlsMux,
        TransportStackKind.tcpRealityVision,
      ]);
    });

    test('promotes last successful stack', () async {
      final serverKey = TransportStackClassifier.serverKey(servers[1]);
      await manager.store.recordAttempt(
        profileId: 'profile-1',
        serverKey: serverKey,
        kind: TransportStackKind.tlsMux,
        success: true,
        latencyMs: 40,
      );
      await manager.store.recordAttempt(
        profileId: 'profile-1',
        serverKey: serverKey,
        kind: TransportStackKind.tlsMux,
        success: true,
        latencyMs: 38,
      );

      final ordered = await manager.orderedProbeList(
        profileId: 'profile-1',
        servers: servers,
        selectedIndex: 0,
      );
      expect(ordered.first.kind, TransportStackKind.tlsMux);
    });
  });
}
