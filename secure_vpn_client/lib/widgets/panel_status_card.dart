import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/panel_sync_status.dart';
import '../providers/panel_providers.dart';

class PanelStatusStrings {
  PanelStatusStrings._();

  static bool _isRu(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'ru';

  static String deviceId(Locale? locale) =>
      _isRu(locale) ? 'ID устройства' : 'Device ID';

  static String lastSync(Locale? locale) =>
      _isRu(locale) ? 'Последняя синхронизация' : 'Last sync';

  static String subscription(Locale? locale) =>
      _isRu(locale) ? 'Подписка' : 'Subscription';

  static String configured(Locale? locale) =>
      _isRu(locale) ? 'Настроено' : 'Configured';

  static String notConfigured(Locale? locale) =>
      _isRu(locale) ? 'Не настроено' : 'Not configured';

  static String never(Locale? locale) =>
      _isRu(locale) ? 'Никогда' : 'Never';
}

class PanelStatusCard extends ConsumerWidget {
  const PanelStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(panelBootstrapProvider);
    final panel = ref.watch(panelStateProvider);
    final manager = ref.watch(panelManagerProvider);
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = panel.settings;

    Color statusColor;
    switch (panel.syncStatus) {
      case PanelSyncStatus.synced:
        statusColor = scheme.primary;
      case PanelSyncStatus.stale:
      case PanelSyncStatus.offline:
        statusColor = scheme.tertiary;
      case PanelSyncStatus.error:
        statusColor = scheme.error;
      case PanelSyncStatus.disabled:
        statusColor = scheme.onSurfaceVariant;
    }

    final lastSync = settings.lastSyncAt == null
        ? PanelStatusStrings.never(locale)
        : settings.lastSyncAt!.toLocal().toString().substring(0, 19);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          panel.syncStatus.label(ru: _isRu(locale)),
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (settings.lastError != null) ...[
          const SizedBox(height: 6),
          Text(
            settings.lastError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _StatusRow(
          label: PanelStatusStrings.deviceId(locale),
          value: manager.deviceIdHash,
        ),
        _StatusRow(
          label: PanelStatusStrings.lastSync(locale),
          value: lastSync,
        ),
        _StatusRow(
          label: PanelStatusStrings.subscription(locale),
          value: settings.subscriptionUrl == null ||
                  settings.subscriptionUrl!.isEmpty
              ? PanelStatusStrings.notConfigured(locale)
              : PanelStatusStrings.configured(locale),
        ),
      ],
    );
  }

  static bool _isRu(Locale locale) => locale.languageCode.toLowerCase() == 'ru';
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
