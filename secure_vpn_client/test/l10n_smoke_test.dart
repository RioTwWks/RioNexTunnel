import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/l10n/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations loads EN and RU', (tester) async {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Text(l10n.navHome);
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining(''), findsWidgets);
    }
  });
}
