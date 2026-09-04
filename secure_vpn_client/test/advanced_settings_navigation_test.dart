import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/l10n/app_localizations.dart';

import 'package:secure_vpn_client/screens/advanced_settings_screen.dart';
import 'package:secure_vpn_client/screens/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('settings navigates to advanced settings screen', (tester) async {
    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('advanced_settings_tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('kill_switch_mode_selector')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('advanced_settings_tile')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AdvancedSettingsScreen), findsOneWidget);
    expect(find.text('Kill switch'), findsOneWidget);
    expect(find.byKey(const ValueKey('kill_switch_mode_selector')), findsOneWidget);
  });

  testWidgets('theme mode defaults to system', (tester) async {
    await pumpSettings(tester);

    final segmentedButton = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(const ValueKey('theme_mode_selector')),
    );
    expect(segmentedButton.selected, {ThemeMode.system});
  });
}
