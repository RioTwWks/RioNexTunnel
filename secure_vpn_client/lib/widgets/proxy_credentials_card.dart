import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/credentials.dart';
import '../utils/config_parser.dart';

/// Desktop proxy credentials card with per-session auth values.
class ProxyCredentialsCard extends StatelessWidget {
  const ProxyCredentialsCard({
    super.key,
    required this.credentials,
    this.showExtensionHint = false,
    this.compact = false,
  });

  final SessionCredentials credentials;
  final bool showExtensionHint;
  final bool compact;

  static bool get isDesktopProxy =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  int get _httpPort => ConfigParser.defaultSocksPort + 1;

  Future<void> _copy(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.proxyCopied(label))),
    );
  }

  Future<void> _copyBoth(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = '${credentials.username}\n${credentials.password}';
    await _copy(context, l10n.proxyCopyBoth, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.proxyCredsTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.proxyCredsDescription(_httpPort),
                style: theme.textTheme.bodySmall,
              ),
              if (showExtensionHint) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.proxyCredsExtensionHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      credentials.username,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l10n.proxyCopyBoth,
                    onPressed: () => _copyBoth(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.proxyCredsTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.proxyCredsDescription(_httpPort),
          style: theme.textTheme.bodySmall,
        ),
        if (showExtensionHint) ...[
          const SizedBox(height: 4),
          Text(
            l10n.proxyCredsExtensionHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(l10n.proxyUsername),
          subtitle: Text(credentials.username),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.proxyUsername,
            onPressed: () => _copy(
              context,
              l10n.proxyUsername,
              credentials.username,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.key_outlined),
          title: Text(l10n.proxyPassword),
          subtitle: Text('${credentials.password.length} characters'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _copyBoth(context),
                child: Text(l10n.proxyCopyBoth),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: l10n.proxyPassword,
                onPressed: () => _copy(
                  context,
                  l10n.proxyPassword,
                  credentials.password,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
