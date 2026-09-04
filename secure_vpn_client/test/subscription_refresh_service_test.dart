import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/subscription_refresh_interval.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/subscription_refresh_service.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/subscription_http_client.dart';

void main() {
  group('sortProfiles', () {
    test('favorites and last used ordering', () {
      final sorted = sortProfiles([
        Profile(id: 'a', name: 'A', configLink: 'vless://a', lastUsedAt: DateTime(2026, 1, 1)),
        const Profile(id: 'b', name: 'B', configLink: 'vless://b', isFavorite: true),
        Profile(id: 'c', name: 'C', configLink: 'vless://c', lastUsedAt: DateTime(2026, 1, 3)),
      ]);
      expect(sorted.map((p) => p.id).toList(), ['b', 'c', 'a']);
    });
  });

  group('SubscriptionRefreshService', () {
    final profile = Profile(
      id: 'sub-1',
      name: 'Sub',
      configLink: 'https://example.com/sub',
      type: ProfileType.subscription,
      subscriptionRefreshInterval: SubscriptionRefreshInterval.hours6,
      lastSubscriptionFetchAt: DateTime(2026, 1, 1, 8),
    );

    test('isDue respects 6h interval', () {
      final service = SubscriptionRefreshService(engine: VpnEngine.xray);
      expect(service.isDue(profile, now: DateTime(2026, 1, 1, 13, 59)), isFalse);
      expect(service.isDue(profile, now: DateTime(2026, 1, 1, 14)), isTrue);
    });

    test('refreshProfile fetches servers', () async {
      ConfigParser.setSubscriptionHttpClientForTesting(
        SubscriptionHttpClient(
          plainClient: MockClient((_) async => http.Response('vless://user@node.example:443', 200)),
        ),
      );
      final service = SubscriptionRefreshService(engine: VpnEngine.singbox);
      final result = await service.refreshProfile(profile);
      expect(result.success, isTrue);
      expect(result.serverCount, 1);
    });
  });
}
