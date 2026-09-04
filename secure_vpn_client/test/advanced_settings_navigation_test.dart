import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secure_vpn_client/screens/advanced_settings_screen.dart';
import 'package:secure_vpn_client/screens/settings_screen.dart';

void main() {
  testWidgets('settings navigates to advanced settings screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('advanced_settings_tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('kill_switch_mode_selector')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('advanced_settings_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(AdvancedSettingsScreen), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.byKey(const ValueKey('kill_switch_mode_selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom_routing_editor_tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('socks_auth_mode_selector')), findsOneWidget);
  });

  testWidgets('theme mode defaults to system', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(const ValueKey('theme_mode_selector')),
    );
    expect(segmentedButton.selected, {ThemeMode.system});
  });
}
