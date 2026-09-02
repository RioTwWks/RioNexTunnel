import 'package:v2ray_box/v2ray_box.dart';

/// High-level connection phase for UI (extends raw [VpnStatus] from the plugin).
enum ConnectionPhase {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  error,
}

/// Rich connection state: phase, optional error/reconnect context.
class ConnectionDetail {
  const ConnectionDetail({
    required this.phase,
    this.reason,
    this.reconnectAttempt = 0,
    this.maxReconnectAttempts = 0,
    this.vpnStatus = VpnStatus.stopped,
  });

  final ConnectionPhase phase;
  final String? reason;
  final int reconnectAttempt;
  final int maxReconnectAttempts;
  final VpnStatus vpnStatus;

  bool get isConnected => phase == ConnectionPhase.connected;

  bool get isTransitioning =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.reconnecting ||
      phase == ConnectionPhase.disconnecting;

  String get displayLabel {
    switch (phase) {
      case ConnectionPhase.disconnected:
        return 'Disconnected';
      case ConnectionPhase.connecting:
        return 'Connecting';
      case ConnectionPhase.connected:
        return 'Connected';
      case ConnectionPhase.reconnecting:
        return reconnectAttempt > 0
            ? 'Reconnecting ($reconnectAttempt/$maxReconnectAttempts)'
            : 'Reconnecting';
      case ConnectionPhase.disconnecting:
        return 'Disconnecting';
      case ConnectionPhase.error:
        return 'Error';
    }
  }

  String? get subtitle {
    if (phase == ConnectionPhase.error && reason != null) {
      return reason;
    }
    if (phase == ConnectionPhase.reconnecting && reason != null) {
      return reason;
    }
    return null;
  }

  factory ConnectionDetail.disconnected() => const ConnectionDetail(
        phase: ConnectionPhase.disconnected,
        vpnStatus: VpnStatus.stopped,
      );

  factory ConnectionDetail.fromVpnStatus(
    VpnStatus status, {
    ConnectionPhase? overridePhase,
    String? reason,
    int reconnectAttempt = 0,
    int maxReconnectAttempts = 0,
  }) {
    final phase = overridePhase ?? _phaseFromVpnStatus(status);
    return ConnectionDetail(
      phase: phase,
      reason: reason,
      reconnectAttempt: reconnectAttempt,
      maxReconnectAttempts: maxReconnectAttempts,
      vpnStatus: status,
    );
  }

  static ConnectionPhase _phaseFromVpnStatus(VpnStatus status) {
    switch (status) {
      case VpnStatus.stopped:
        return ConnectionPhase.disconnected;
      case VpnStatus.starting:
        return ConnectionPhase.connecting;
      case VpnStatus.started:
        return ConnectionPhase.connected;
      case VpnStatus.stopping:
        return ConnectionPhase.disconnecting;
    }
  }

  ConnectionDetail copyWith({
    ConnectionPhase? phase,
    String? reason,
    int? reconnectAttempt,
    int? maxReconnectAttempts,
    VpnStatus? vpnStatus,
    bool clearReason = false,
  }) {
    return ConnectionDetail(
      phase: phase ?? this.phase,
      reason: clearReason ? null : (reason ?? this.reason),
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      vpnStatus: vpnStatus ?? this.vpnStatus,
    );
  }
}
