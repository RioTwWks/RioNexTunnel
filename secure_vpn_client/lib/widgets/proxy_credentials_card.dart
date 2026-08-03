import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/credentials.dart';
import '../utils/config_parser.dart';

/// Localized strings for the proxy credentials card (RU / EN).
class ProxyCredentialsStrings {
  ProxyCredentialsStrings._();

  static bool _isRu(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'ru';

  static String title(Locale? locale) => _isRu(locale)
      ? 'Системный прокси (эта сессия)'
      : 'System proxy (this session)';

  static String description(Locale? locale, int httpPort) => _isRu(locale)
      ? 'Если браузер запрашивает логин прокси, используйте эти значения. '
          'Это не аккаунт VPN-сервера — только локальный прокси '
          '127.0.0.1:$httpPort.'
      : 'If the browser asks for proxy login, use these values. '
          'They are not your VPN server account — only for local proxy '
          '127.0.0.1:$httpPort.';

  static String extensionHint(Locale? locale) => _isRu(locale)
      ? 'Установите расширение Browser helper (Settings), чтобы не вводить '
          'логин вручную.'
      : 'Install the Browser helper extension (Settings) to skip manual login.';

  static String username(Locale? locale) =>
      _isRu(locale) ? 'Имя пользователя прокси' : 'Proxy username';

  static String password(Locale? locale) =>
      _isRu(locale) ? 'Пароль прокси' : 'Proxy password';

  static String copyBoth(Locale? locale) =>
      _isRu(locale) ? 'Копировать оба' : 'Copy both';

  static String copied(Locale? locale, String label) => _isRu(locale)
      ? '$label скопировано'
      : '$label copied';
}

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
    final locale = Localizations.localeOf(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ProxyCredentialsStrings.copied(locale, label))),
    );
  }

  Future<void> _copyBoth(BuildContext context) async {
    final text = '${credentials.username}\n${credentials.password}';
    await _copy(context, ProxyCredentialsStrings.copyBoth(
      Localizations.localeOf(context),
    ), text);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ProxyCredentialsStrings.title(locale),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                ProxyCredentialsStrings.description(locale, _httpPort),
                style: theme.textTheme.bodySmall,
              ),
              if (showExtensionHint) ...[
                const SizedBox(height: 4),
                Text(
                  ProxyCredentialsStrings.extensionHint(locale),
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
                    tooltip: ProxyCredentialsStrings.copyBoth(locale),
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
          ProxyCredentialsStrings.title(locale),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          ProxyCredentialsStrings.description(locale, _httpPort),
          style: theme.textTheme.bodySmall,
        ),
        if (showExtensionHint) ...[
          const SizedBox(height: 4),
          Text(
            ProxyCredentialsStrings.extensionHint(locale),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(ProxyCredentialsStrings.username(locale)),
          subtitle: Text(credentials.username),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: ProxyCredentialsStrings.username(locale),
            onPressed: () => _copy(
              context,
              ProxyCredentialsStrings.username(locale),
              credentials.username,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.key_outlined),
          title: Text(ProxyCredentialsStrings.password(locale)),
          subtitle: Text('${credentials.password.length} characters'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _copyBoth(context),
                child: Text(ProxyCredentialsStrings.copyBoth(locale)),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: ProxyCredentialsStrings.password(locale),
                onPressed: () => _copy(
                  context,
                  ProxyCredentialsStrings.password(locale),
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
