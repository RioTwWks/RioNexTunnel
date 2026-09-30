import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/profile_config_isolate.dart';

void main() {
  test('buildProfileConfigInIsolate builds from vless link', () {
    const link =
        'vless://00000000-0000-0000-0000-000000000001@example.com:443'
        '?security=reality&type=xhttp&path=%2F#test';
    const profile = Profile(
      id: 'p1',
      name: 'test',
      configLink: 'https://example.com/sub',
      type: ProfileType.subscription,
    );

    final json = buildProfileConfigInIsolate(
      ProfileConfigIsolateInput(
        raw: link,
        profileJson: profile.toJson(),
        engineCoreName: VpnEngine.xray.coreName,
        customRulesJson: const [],
      ),
    );

    expect(json.contains('"outbounds"'), isTrue);
    expect(json.contains('xhttp'), isTrue);
  });
}
