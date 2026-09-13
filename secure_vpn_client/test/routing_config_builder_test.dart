import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/routing_rule.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/routing_config_builder.dart';

void main() {
  test('prepends xray user rules', () {
    final config = <String, dynamic>{
      'routing': {
        'rules': [
          {
            'type': 'field',
            'domain': ['sub.example'],
            'outboundTag': 'proxy',
          },
        ],
      },
    };
    RoutingConfigBuilder.mergeUserRulesIntoConfig(
      config,
      const [
        RoutingRule(
          id: '1',
          type: RoutingRuleType.domain,
          values: ['user.example'],
          outbound: RoutingOutboundAction.direct,
        ),
      ],
      VpnEngine.xray,
    );
    final rules = (config['routing'] as Map)['rules'] as List;
    expect((rules.first as Map)['domain'], ['user.example']);
  });

  test('ru preset uses geosite/geoip for xray', () {
    final config = <String, dynamic>{'routing': {'rules': <dynamic>[]}};
    RoutingConfigBuilder.mergeUserRulesIntoConfig(
      config,
      RoutingPresetRegistry.rulesFor(RoutingPresetId.ruDirect),
      VpnEngine.xray,
    );
    expect(jsonEncode(config), contains('geosite:ru'));
    expect(jsonEncode(config), contains('geoip:ru'));
  });

  test('ru preset uses geosite/geoip for sing-box', () {
    final config = <String, dynamic>{'route': {'rules': <dynamic>[]}};
    RoutingConfigBuilder.mergeUserRulesIntoConfig(
      config,
      RoutingPresetRegistry.rulesFor(RoutingPresetId.ruDirect),
      VpnEngine.singbox,
    );
    final rules = (config['route'] as Map)['rules'] as List;
    expect((rules.first as Map)['geosite'], ['ru']);
    expect((rules[1] as Map)['geoip'], ['ru']);
  });
}
