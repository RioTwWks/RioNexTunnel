import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/providers/vpn_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SelectedProfileNotifier', () {
    Future<void> waitForProviders(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('restores last selected profile on startup', (tester) async {
      final profile = Profile(
        id: 'profile-1',
        name: 'My VPN',
        configLink: 'https://example.com/sub',
        type: ProfileType.subscription,
        selectedServerIndex: 2,
        selectedServerName: 'Node 3',
      );

      SharedPreferences.setMockInitialValues({
        'vpn_profiles': jsonEncode([profile.toJson()]),
        'selected_profile_id': profile.id,
      });

      final container = ProviderContainer();
      await waitForProviders(tester);

      final selected = container.read(selectedProfileProvider);
      expect(selected?.id, profile.id);
      expect(selected?.name, profile.name);
      expect(selected?.selectedServerIndex, 2);
      expect(selected?.selectedServerName, 'Node 3');

      container.dispose();
    });

    testWidgets('persists selection and clears when profile removed', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      await waitForProviders(tester);

      await container.read(profilesProvider.notifier).addProfile(
            name: 'Link profile',
            configLink: 'vless://example.com',
          );

      final saved = container.read(profilesProvider).first;
      await container.read(selectedProfileProvider.notifier).select(saved);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_profile_id'), saved.id);

      await container.read(profilesProvider.notifier).removeProfile(saved.id);
      await waitForProviders(tester);

      expect(container.read(selectedProfileProvider), isNull);
      expect(prefs.getString('selected_profile_id'), isNull);

      container.dispose();
    });
  });
}
