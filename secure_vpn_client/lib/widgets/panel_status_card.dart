import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/panel_sync_status.dart';
import '../l10n/app_localizations.dart';
import '../providers/panel_providers.dart';
import '../utils/l10n_helpers.dart';

class PanelStatusCard extends ConsumerWidget {
  const PanelStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(panelBootstrapProvider);
    final panel = ref.watch(panelStateProvider);
    final manager = ref.watch(panelManagerProvider);
    final l10n = AppLocalizations.of(context)!;
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
        ? l10n.panelNever
        : settings.lastSyncAt!.toLocal().toString().substring(0, 19);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          panelSyncStatusLabel(l10n, panel.syncStatus),
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
          label: l10n.panelDeviceId,
          value: manager.deviceIdHash,
        ),
        _StatusRow(
          label: l10n.panelLastSync,
          value: lastSync,
        ),
        _StatusRow(
          label: l10n.panelSubscription,
          value: settings.subscriptionUrl == null ||
                  settings.subscriptionUrl!.isEmpty
              ? l10n.panelNotConfigured
              : l10n.panelConfigured,
        ),
      ],
    );
  }

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
