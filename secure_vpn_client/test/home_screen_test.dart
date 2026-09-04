import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secure_vpn_client/models/profile.dart';
import 'package:secure_vpn_client/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForProfiles(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('home screen shows disconnected state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );
    await waitForProfiles(tester);

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_quick_picker')), findsOneWidget);
  });

  testWidgets('profile quick picker switches active profile', (tester) async {
    const profileA = Profile(
      id: 'profile-a',
      name: 'Alpha VPN',
      configLink: 'vless://alpha.example.com',
    );
    const profileB = Profile(
      id: 'profile-b',
      name: 'Beta VPN',
      configLink: 'vless://beta.example.com',
    );

    SharedPreferences.setMockInitialValues({
      'vpn_profiles': jsonEncode([profileA.toJson(), profileB.toJson()]),
      'selected_profile_id': profileA.id,
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );
    await waitForProfiles(tester);

    expect(find.text('Alpha VPN'), findsOneWidget);
    expect(find.textContaining('vless://'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile_quick_picker')));
    await tester.pumpAndSettle();

    expect(find.text('Active profile'), findsOneWidget);
    expect(find.text('Beta VPN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_option_profile-b')));
    await tester.pumpAndSettle();

    expect(find.text('Beta VPN'), findsOneWidget);
    expect(find.text('Alpha VPN'), findsNothing);
  });
}
