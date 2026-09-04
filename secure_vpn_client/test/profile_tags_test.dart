import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/models/subscription_refresh_interval.dart';
import 'package:secure_vpn_client/providers/vpn_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('persists tags favorites and refresh metadata', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    await tester.pump();

    await container.read(profilesProvider.notifier).addProfile(
          name: 'Work',
          configLink: 'https://example.com/sub',
          type: ProfileType.subscription,
          tags: ['work'],
          isFavorite: true,
        );
    final id = container.read(profilesProvider).single.id;
    await container.read(profilesProvider.notifier).setTags(id, ['work', 'travel']);
    await container.read(profilesProvider.notifier).setSubscriptionRefreshInterval(
          id,
          SubscriptionRefreshInterval.hours12,
        );
    await container.read(profilesProvider.notifier).recordSubscriptionFetch(id);
    await container.read(profilesProvider.notifier).markLastUsed(id);

    final profile = container.read(profilesProvider).single;
    expect(profile.tags, ['work', 'travel']);
    expect(profile.isFavorite, isTrue);
    expect(profile.subscriptionRefreshInterval, SubscriptionRefreshInterval.hours12);
    expect(profile.lastSubscriptionFetchAt, isNotNull);
    expect(profile.lastUsedAt, isNotNull);
    expect(container.read(favoriteProfilesProvider), hasLength(1));

    final raw = (await SharedPreferences.getInstance()).getString('vpn_profiles');
    final map = (jsonDecode(raw!) as List).single as Map<String, dynamic>;
    expect(map['tags'], ['work', 'travel']);
    container.dispose();
  });
}
