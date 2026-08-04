import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/engine_preference.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/engine_auto_selector.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';

void main() {
  group('EnginePreference', () {
    test('parses storage values', () {
      expect(EnginePreference.fromStorage('auto'), EnginePreference.auto);
      expect(EnginePreference.fromStorage('xray'), EnginePreference.xray);
      expect(EnginePreference.fromStorage('singbox'), EnginePreference.singbox);
      expect(EnginePreference.fromStorage(null), EnginePreference.auto);
    });
  });

  group('EngineAutoSelector.needsXrayGeo', () {
    test('detects geosite/geoip rules', () {
      expect(
        EngineAutoSelector.needsXrayGeo(
          '{"routing":{"rules":[{"domain":["geosite:cn"]}]}}',
        ),
        isTrue,
      );
      expect(EngineAutoSelector.needsXrayGeo('{"outbounds":[]}'), isFalse);
    });
  });

  group('EngineResolution', () {
    test('preferred is first attempt', () {
      const resolution = EngineResolution(
        attemptOrder: [VpnEngine.singbox, VpnEngine.xray],
        reason: 'test',
      );
      expect(resolution.preferred, VpnEngine.singbox);
    });
  });

  group('sing-box-only link detection', () {
    test('hy2 profile is flagged for sing-box', () {
      const profile = Profile(
        id: '1',
        name: 'hy2',
        configLink: 'hy2://pw@host:443',
        type: ProfileType.link,
      );
      expect(LinkConfigBuilder.requiresSingbox(profile.configLink), isTrue);
    });
  });
}
