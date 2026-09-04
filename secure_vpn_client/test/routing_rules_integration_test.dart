import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/routing_rule.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/config_enhancer.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';
import 'package:secure_vpn_client/utils/routing_config_builder.dart';

void main() {
  const link =
      'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';

  test('ConfigEnhancer merges custom and RU direct rules', () {
    final base = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
    const profile = Profile(
      id: 'p1',
      name: 'test',
      configLink: link,
      ruDirectRouting: true,
    );
    final enhanced = ConfigEnhancer.applyProfileSettings(
      base,
      profile,
      VpnEngine.xray,
      customRules: const [
        RoutingRule(
          id: 'c1',
          type: RoutingRuleType.domain,
          values: ['local.example'],
          outbound: RoutingOutboundAction.direct,
        ),
      ],
    );
    final rules =
        ((jsonDecode(enhanced) as Map)['routing'] as Map)['rules'] as List;
    expect((rules.first as Map)['domain'], contains('geosite:ru'));
    expect(ConfigParser.configRequiresXrayGeoRules(enhanced), isTrue);
    expect(
      RoutingConfigBuilder.rulesRequireGeoAssets(
        RoutingPresetRegistry.rulesFor(RoutingPresetId.ruDirect),
      ),
      isTrue,
    );
  });
}
