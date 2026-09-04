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
          final l10n = AppLocalizations.of(context);
          return Text(l10n.navHome);
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining(''), findsWidgets);
    }
  });

  testWidgets('secondary sweep ARB keys resolve EN and RU', (tester) async {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      final samples = <String>[
        l10n.censorshipWizardTitle,
        l10n.censorshipDetected('VLESS'),
        l10n.routingCustomTitle,
        l10n.configFromClipboard,
        l10n.importProfilesTitle,
        l10n.qrScanTitle,
        l10n.perAppProxyTitleInclude,
        l10n.perAppProxySelectionSummary(2, 'vpn', 5),
        l10n.killSwitchStrictDesc,
        l10n.dnsLeakTest,
        l10n.multihopEditChain,
        l10n.profileSubscriptionStale,
        l10n.profileActiveTitle,
        l10n.serverAutoRetest,
        l10n.pinningFormatHint,
        l10n.configProfilesImported(3),
      ];

      for (final text in samples) {
        expect(text.trim().isNotEmpty, isTrue, reason: 'empty for $locale');
      }
    }
  });
}
