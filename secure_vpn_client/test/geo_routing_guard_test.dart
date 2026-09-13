import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/config_enhancer.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';

void main() {
  const link =
      'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls';

  test('RU direct sing-box config requires geo assets', () {
    final base = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
    const profile = Profile(
      id: 'p1',
      name: 'test',
      configLink: link,
      ruDirectRouting: true,
    );
    final enhanced = ConfigEnhancer.applyProfileSettings(
      base,
      profile,
      VpnEngine.singbox,
    );
    expect(ConfigParser.configRequiresGeoRules(enhanced), isTrue);
    expect(ConfigParser.configRequiresXrayGeoRules(enhanced), isFalse);

    final route = (jsonDecode(enhanced) as Map)['route'] as Map;
    final rules = route['rules'] as List;
    expect((rules.first as Map)['geosite'], ['ru']);
  });

  test('plain sing-box config without geo rules does not require geo assets', () {
    final base = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
    expect(ConfigParser.configRequiresGeoRules(base), isFalse);
  });
}
