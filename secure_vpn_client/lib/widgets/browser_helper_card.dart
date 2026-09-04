import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/vpn_providers.dart';

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

    final l10n = AppLocalizations.of(context);
    final statusAsync = ref.watch(browserHelperStatusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.browserHelperTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.browserHelperDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            statusAsync.when(
              data: (status) => _StatusBody(status: status, l10n: l10n),
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
    required this.l10n,
  });

  final Map<String, bool> status;
  final AppLocalizations l10n;

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
      summary = l10n.browserHelperReady;
      summaryColor = Theme.of(context).colorScheme.primary;
    } else if (!host) {
      summary = l10n.browserHelperHostMissing;
      summaryColor = Theme.of(context).colorScheme.error;
    } else if (!manifest) {
      summary = l10n.browserHelperManifestMissing;
      summaryColor = Theme.of(context).colorScheme.error;
    } else if (!extension) {
      summary = l10n.browserHelperExtensionMissing;
      summaryColor = Theme.of(context).colorScheme.tertiary;
    } else {
      summary = l10n.browserHelperWaiting;
      summaryColor = Theme.of(context).colorScheme.tertiary;
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
          label: l10n.browserHelperLabelHost,
          ok: host,
        ),
        _StatusRow(
          label: l10n.browserHelperLabelManifest,
          ok: manifest,
        ),
        _StatusRow(
          label: l10n.browserHelperLabelExtension,
          ok: extension,
        ),
        _StatusRow(
          label: l10n.browserHelperLabelSession,
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
          color: ok
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).disabledColor,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
