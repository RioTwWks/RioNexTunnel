import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/subscription_server.dart';
import 'package:secure_vpn_client/models/transport_stack.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/subscription_manager.dart';
import 'package:secure_vpn_client/services/transport_stack_store.dart';
import 'package:secure_vpn_client/services/vpn_service.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uuid = '11111111-2222-3333-4444-555555555555';
  const xhttp =
      'vless://$uuid@example.com:443?security=reality&type=xhttp&mode=stream-one&pbk=a&sid=b&sni=cdn.example.com#XHTTP';
  const tlsMux =
      'vless://$uuid@example.com:443?security=tls&type=tcp#TLS-mux';
  const awg =
      'awg://CLIENT@vpn.example:51820?publickey=SERVER&address=10.8.1.2/32'
      '&jc=4&jmin=40&jmax=70#AWG';

  test('mock failure on first outbound falls back to second profile fragment', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = SubscriptionManager(store: TransportStackStore());
    final stacks = await manager.orderedProbeList(
      profileId: 'p1',
      servers: [
        const SubscriptionServer(index: 0, name: 'XHTTP', content: xhttp),
        const SubscriptionServer(index: 1, name: 'TLS mux', content: tlsMux),
      ],
      selectedIndex: 0,
    );
    expect(stacks.first.kind, TransportStackKind.xhttpReality);

    const profile = Profile(
      id: 'p1',
      name: 'fallback-test',
      configLink: 'https://example.com/sub',
      type: ProfileType.subscription,
      selectedServerIndex: 0,
    );
    final service = VpnService(subscriptionManager: manager);

    TransportStackCandidate? connected;
    Object? firstError;
    for (final stack in stacks) {
      try {
        final raw = stack.content;
        final json = LinkConfigBuilder.buildFromLink(raw, VpnEngine.xray);
        final outbound = (jsonDecode(json) as Map)['outbounds'].first as Map;
        final network =
            ((outbound['streamSettings'] as Map?)?['network'] ?? 'tcp')
                .toString();
        if (network == 'xhttp') {
          throw StateError('mock outbound failure');
        }
        await service.resolveProfileConfig(profile, contentOverride: raw);
        connected = stack;
        break;
      } catch (error) {
        firstError ??= error;
      }
    }

    expect(firstError, isNotNull);
    expect(connected, isNotNull);
    expect(connected!.kind, TransportStackKind.tlsMux);
    expect(connected.content, tlsMux);
  });

  test('fallback chain includes AmneziaWG when present in subscription', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = SubscriptionManager(store: TransportStackStore());
    final stacks = await manager.orderedProbeList(
      profileId: 'p1',
      servers: [
        const SubscriptionServer(index: 0, name: 'XHTTP', content: xhttp),
        const SubscriptionServer(index: 1, name: 'TLS mux', content: tlsMux),
        const SubscriptionServer(index: 2, name: 'AWG', content: awg),
      ],
      selectedIndex: 0,
    );

    expect(stacks.map((s) => s.kind).toList(), contains(TransportStackKind.amneziaWg));
    final awgStack = stacks.firstWhere((s) => s.kind == TransportStackKind.amneziaWg);
    final json = LinkConfigBuilder.buildFromLink(awgStack.content, VpnEngine.singbox);
    final outbound = (jsonDecode(json) as Map)['outbounds'].first as Map;
    expect(outbound['jc'], 4);
  });
}
