import '../l10n/app_localizations.dart';
import '../models/connection_detail.dart';
import '../models/panel_sync_status.dart';
import '../models/split_tunnel_settings.dart';
import '../models/transport_preset.dart';

String connectionPhaseLabelFromStatus(
  AppLocalizations l10n, ConnectionPhase phase, {int reconnectAttempt=0, int maxReconnectAttempts=0}) {
  return connectionPhaseLabel(l10n, ConnectionDetail(phase: phase, reconnectAttempt: reconnectAttempt, maxReconnectAttempts: maxReconnectAttempts));
}

String connectionPhaseLabel(AppLocalizations l10n, ConnectionDetail detail) {
  switch (detail.phase) {
    case ConnectionPhase.disconnected:
      return l10n.connectionDisconnected;
    case ConnectionPhase.connecting:
      return l10n.connectionConnecting;
    case ConnectionPhase.connected:
      return l10n.connectionConnected;
    case ConnectionPhase.reconnecting:
      if (detail.reconnectAttempt > 0 && detail.maxReconnectAttempts > 0) {
        return l10n.connectionReconnectingAttempt(
          detail.reconnectAttempt,
          detail.maxReconnectAttempts,
        );
      }
      return l10n.connectionReconnecting;
    case ConnectionPhase.disconnecting:
      return l10n.connectionDisconnecting;
    case ConnectionPhase.error:
      return l10n.connectionError;
  }
}

String panelSyncStatusLabel(AppLocalizations l10n, PanelSyncStatus status) {
  switch (status) {
    case PanelSyncStatus.disabled:
      return l10n.panelSyncDisabled;
    case PanelSyncStatus.synced:
      return l10n.panelSyncSynced;
    case PanelSyncStatus.stale:
      return l10n.panelSyncStale;
    case PanelSyncStatus.offline:
      return l10n.panelSyncOffline;
    case PanelSyncStatus.error:
      return l10n.panelSyncError;
  }
}

String splitTunnelModeDescription(
  AppLocalizations l10n,
  SplitTunnelMode mode,
) {
  switch (mode) {
    case SplitTunnelMode.off:
      return l10n.splitTunnelModeOffDesc;
    case SplitTunnelMode.include:
      return l10n.splitTunnelModeIncludeDesc;
    case SplitTunnelMode.exclude:
      return l10n.splitTunnelModeExcludeDesc;
  }
}

String formatUptime(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return l10n.uptimeHoursMinutes(hours, minutes);
  }
  if (minutes > 0) {
    return l10n.uptimeMinutesSeconds(minutes, seconds);
  }
  return l10n.uptimeSeconds(seconds);
}

String transportStackSummary(
  AppLocalizations l10n, {
  required bool censorshipModeEnabled,
  TransportPresetId? transportPreset,
  required String tlsFingerprint,
  required bool muxEnabled,
  required bool ruDirectRouting,
  required String detectedSummary,
}) {
  if (censorshipModeEnabled) {
    final parts = <String>[
      transportPreset?.shortLabel ?? l10n.transportCustom,
      tlsFingerprint,
      if (muxEnabled) l10n.transportMux,
      if (ruDirectRouting) l10n.transportRuDirect,
    ];
    return parts.join(' · ');
  }
  if (detectedSummary.isNotEmpty) {
    return detectedSummary;
  }
  return l10n.transportStandard;
}
