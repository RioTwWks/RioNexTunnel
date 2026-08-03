import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vpn_providers.dart';

class BrowserHelperStrings {
  BrowserHelperStrings._();

  static bool _isRu(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'ru';

  static String title(Locale? locale) =>
      _isRu(locale) ? 'Помощник браузера' : 'Browser helper';

  static String description(Locale? locale) => _isRu(locale)
      ? 'Один раз установите расширение из extensions/secure-vpn-proxy-auth. '
          'Оно автоматически подставляет логин прокси — без диалога в Chromium и Firefox.'
      : 'Install the extension once from extensions/secure-vpn-proxy-auth. '
          'It auto-fills proxy login for Chromium and Firefox.';

  static String ready(Locale? locale) =>
      _isRu(locale) ? 'Готово — диалог не нужен' : 'Ready — no login dialog';

  static String waiting(Locale? locale) => _isRu(locale)
      ? 'Подключите VPN и откройте расширение в браузере'
      : 'Connect VPN and enable the browser extension';

  static String hostMissing(Locale? locale) => _isRu(locale)
      ? 'Native host не установлен — перезапустите приложение'
      : 'Native host missing — restart the app';

  static String manifestMissing(Locale? locale) => _isRu(locale)
      ? 'Манифест native messaging не найден'
      : 'Native messaging manifest not found';

  static String extensionMissing(Locale? locale) => _isRu(locale)
      ? 'Расширение не подключено к native host'
      : 'Extension not connected to native host';

  static String labelHost(Locale? locale) =>
      _isRu(locale) ? 'Native host' : 'Native host';

  static String labelManifest(Locale? locale) =>
      _isRu(locale) ? 'Манифест' : 'Manifest';

  static String labelExtension(Locale? locale) =>
      _isRu(locale) ? 'Расширение' : 'Extension';

  static String labelSession(Locale? locale) =>
      _isRu(locale) ? 'Сессия VPN' : 'VPN session';
}

final browserHelperStatusProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  ref.watch(vpnStatusProvider);
  if (kIsWeb ||
      !(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    return {};
  }
  return ref.watch(vpnServiceProvider).v2rayBox.getBrowserHelperStatus();
});

class BrowserHelperCard extends ConsumerWidget {
  const BrowserHelperCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb ||
        !(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    final locale = Localizations.localeOf(context);
    final statusAsync = ref.watch(browserHelperStatusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BrowserHelperStrings.title(locale),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              BrowserHelperStrings.description(locale),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            statusAsync.when(
              data: (status) => _StatusBody(status: status, locale: locale),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.status,
    required this.locale,
  });

  final Map<String, bool> status;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final ready = status['ready'] == true;
    final host = status['hostInstalled'] == true;
    final manifest = status['manifestInstalled'] == true;
    final extension = status['extensionConnected'] == true;
    final session = status['credentialsActive'] == true;

    String summary;
    Color summaryColor;
    if (ready) {
      summary = BrowserHelperStrings.ready(locale);
      summaryColor = Colors.green.shade700;
    } else if (!host) {
      summary = BrowserHelperStrings.hostMissing(locale);
      summaryColor = Theme.of(context).colorScheme.error;
    } else if (!manifest) {
      summary = BrowserHelperStrings.manifestMissing(locale);
      summaryColor = Theme.of(context).colorScheme.error;
    } else if (!extension) {
      summary = BrowserHelperStrings.extensionMissing(locale);
      summaryColor = Colors.orange.shade800;
    } else {
      summary = BrowserHelperStrings.waiting(locale);
      summaryColor = Colors.orange.shade800;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style: TextStyle(
            color: summaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: BrowserHelperStrings.labelHost(locale),
          ok: host,
        ),
        _StatusRow(
          label: BrowserHelperStrings.labelManifest(locale),
          ok: manifest,
        ),
        _StatusRow(
          label: BrowserHelperStrings.labelExtension(locale),
          ok: extension,
        ),
        _StatusRow(
          label: BrowserHelperStrings.labelSession(locale),
          ok: session,
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.green.shade700 : Theme.of(context).disabledColor,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
