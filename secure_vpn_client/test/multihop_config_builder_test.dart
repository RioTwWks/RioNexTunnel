import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/multihop_chain.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/config_enhancer.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/multihop_config_builder.dart';

void main() {
  final credentials = CredentialService().generate();

  Map<String, dynamic> xrayHop(String address) => {
        'inbounds': <dynamic>[],
        'outbounds': [
          {
            'tag': 'proxy',
            'protocol': 'vless',
            'settings': {
              'vnext': [
                {
                  'address': address,
                  'port': 443,
                  'users': [
                    {'id': '00000000-0000-0000-0000-000000000001'},
                  ],
                },
              ],
            },
          },
          {'tag': 'direct', 'protocol': 'freedom'},
        ],
      };

  Map<String, dynamic> singboxHop(String server) => {
        'inbounds': <dynamic>[],
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'proxy',
            'server': server,
            'server_port': 443,
            'uuid': '00000000-0000-0000-0000-000000000001',
          },
          {'type': 'direct', 'tag': 'direct'},
        ],
      };

  test('xray chain links entry hop through exit proxySettings', () {
    final merged = MultihopConfigBuilder.build(
      [xrayHop('entry.example'), xrayHop('exit.example')],
      VpnEngine.xray,
    );
    final outbounds = merged['outbounds'] as List;
    expect((outbounds[0] as Map)['tag'], 'hop-0');
    expect((outbounds[1] as Map)['proxySettings'], {'tag': 'hop-0'});
  });

  test('sing-box chain uses detour on exit outbound', () {
    final merged = MultihopConfigBuilder.build(
      [singboxHop('entry.example'), singboxHop('exit.example')],
      VpnEngine.singbox,
    );
    final outbounds = merged['outbounds'] as List;
    expect((outbounds[1] as Map)['detour'], 'hop-0');
  });

  test('rejects duplicate hop indices', () {
    const profile = Profile(
      id: 'p1',
      name: 'sub',
      configLink: 'https://example.com/sub',
      type: ProfileType.subscription,
      multihopEnabled: true,
      hopServerIndices: [0, 1],
    );
    expect(
      () => MultihopChain.validateProfile(profile, serverCount: 3),
      throwsA(isA<MultihopChainException>()),
    );
  });

  test('injectSecureSocksInbound preserves xray multihop chain', () {
    final merged = MultihopConfigBuilder.build(
      [xrayHop('entry.example'), xrayHop('exit.example')],
      VpnEngine.xray,
    );
    final secured = ConfigParser.injectSecureSocksInbound(
      jsonEncode(merged),
      credentials,
      VpnEngine.xray,
      proxyOnly: true,
    );
    final decoded = jsonDecode(secured) as Map<String, dynamic>;
    final exit = (decoded['outbounds'] as List).firstWhere(
      (raw) => (raw as Map)['tag'] == 'proxy',
    ) as Map;
    expect(exit['proxySettings'], {'tag': 'hop-0'});
    final socks = (decoded['inbounds'] as List).cast<Map>().firstWhere(
          (inbound) => inbound['tag'] == 'secure-socks-in',
        );
    expect(socks['listen'], '127.0.0.1');
  });

  test('ConfigEnhancer merges hop configs when enabled', () {
    const profile = Profile(
      id: 'p1',
      name: 'sub',
      configLink: 'https://example.com/sub',
      type: ProfileType.subscription,
      multihopEnabled: true,
      hopServerIndices: [1],
    );
    final hops = [xrayHop('entry.example'), xrayHop('exit.example')];
    final result = ConfigEnhancer.applyProfileSettings(
      jsonEncode(hops.last),
      profile,
      VpnEngine.xray,
      multihopHopConfigs: hops,
    );
    final exit = (jsonDecode(result) as Map)['outbounds'][1] as Map;
    expect(exit['proxySettings'], {'tag': 'hop-0'});
  });
}
