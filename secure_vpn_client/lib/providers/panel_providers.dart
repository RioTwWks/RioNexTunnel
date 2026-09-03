import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/panel_settings.dart';
import '../models/panel_sync_status.dart';
import '../models/profile.dart';
import '../services/panel_command_service.dart';
import '../services/panel_manager.dart';
import 'vpn_providers.dart';

const panelProfileName = 'RioNexGate';
const _panelProfileName = panelProfileName;

final panelManagerProvider = Provider<PanelManager>((ref) {
  final manager = PanelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final panelCommandServiceProvider = Provider<PanelCommandService>((ref) {
  final service = PanelCommandService(
    panelManager: ref.watch(panelManagerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final panelBootstrapProvider = FutureProvider<void>((ref) async {
  final manager = ref.watch(panelManagerProvider);
  await manager.load();
});

class PanelState {
  const PanelState({
    required this.settings,
    required this.syncStatus,
    this.busy = false,
  });

  final PanelSettings settings;
  final PanelSyncStatus syncStatus;
  final bool busy;

  PanelState copyWith({
    PanelSettings? settings,
    PanelSyncStatus? syncStatus,
    bool? busy,
  }) {
    return PanelState(
      settings: settings ?? this.settings,
      syncStatus: syncStatus ?? this.syncStatus,
      busy: busy ?? this.busy,
    );
  }
}

final panelStateProvider =
    StateNotifierProvider<PanelStateNotifier, PanelState>((ref) {
      return PanelStateNotifier(ref);
    });

class PanelStateNotifier extends StateNotifier<PanelState> {
  PanelStateNotifier(this._ref)
    : super(
        const PanelState(
          settings: PanelSettings(),
          syncStatus: PanelSyncStatus.disabled,
        ),
      ) {
    _init();
  }

  final Ref _ref;

  PanelManager get _manager => _ref.read(panelManagerProvider);

  Future<void> _init() async {
    await _ref.read(panelBootstrapProvider.future);
    _refreshFromManager();
  }

  void _refreshFromManager() {
    state = PanelState(
      settings: _manager.settings,
      syncStatus: _manager.syncStatus,
      busy: state.busy,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _manager.setEnabled(enabled);
    _refreshFromManager();
  }

  Future<void> savePanelUrl(String panelUrl) async {
    await _manager.updatePanelUrl(panelUrl);
    _refreshFromManager();
  }

  Future<void> clearRegistration() async {
    state = state.copyWith(busy: true);
    try {
      await _manager.clearRegistration();
      await _removePanelProfile();
      _refreshFromManager();
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> register(String pairingToken) async {
    state = state.copyWith(busy: true);
    try {
      final result = await _manager.register(pairingToken: pairingToken);
      await _upsertPanelProfile(result.subscriptionUrl);
      await _manager.syncConfig();
      await _manager.flushStats();
      _refreshFromManager();
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> refreshConfig() async {
    if (!_manager.isActive) {
      return;
    }
    state = state.copyWith(busy: true);
    try {
      final result = await _manager.syncConfig(force: true);
      if (result?.subscriptionUrl != null) {
        await _upsertPanelProfile(result!.subscriptionUrl);
      }
      await _manager.flushStats();
      _refreshFromManager();
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> handleRemoteRefreshConfig() async {
    await refreshConfig();
    await _reconnectPanelProfileIfConnected();
  }

  Future<void> handleRemoteDisconnect() async {
    await _ref.read(vpnServiceProvider).disconnect();
  }

  Future<void> handleRemoteSwitchServer({
    int? serverIndex,
    String? serverName,
  }) async {
    final profile = _panelProfile();
    if (profile == null) {
      return;
    }
    final index = serverIndex ?? profile.selectedServerIndex;
    final updated = await _ref.read(profilesProvider.notifier).selectServer(
      profileId: profile.id,
      serverIndex: index,
      serverName: serverName,
      autoSelectBestServer: false,
    );
    if (updated == null) {
      return;
    }
    await _ref.read(selectedProfileProvider.notifier).select(updated);
    await _reconnectPanelProfileIfConnected(updated);
  }

  Profile? _panelProfile() {
    for (final profile in _ref.read(profilesProvider)) {
      if (profile.name == _panelProfileName) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _reconnectPanelProfileIfConnected([Profile? profile]) async {
    final vpn = _ref.read(vpnServiceProvider);
    if (vpn.currentStatus != VpnStatus.started) {
      return;
    }
    final panelProfile = profile ?? _panelProfile();
    if (panelProfile == null) {
      return;
    }
    final selected = _ref.read(selectedProfileProvider);
    if (selected?.id != panelProfile.id) {
      return;
    }
    final result = await vpn.connect(panelProfile);
    _ref.read(engineProvider.notifier).noteActiveEngine(result.engine);
    final connectedProfile = result.profile;
    if (connectedProfile.selectedServerIndex != panelProfile.selectedServerIndex ||
        connectedProfile.selectedServerName != panelProfile.selectedServerName) {
      final synced = await _ref.read(profilesProvider.notifier).selectServer(
        profileId: connectedProfile.id,
        serverIndex: connectedProfile.selectedServerIndex,
        serverName: connectedProfile.selectedServerName,
        autoSelectBestServer: connectedProfile.autoSelectBestServer,
      );
      if (synced != null) {
        await _ref.read(selectedProfileProvider.notifier).select(synced);
      }
    }
  }

  Future<void> _upsertPanelProfile(String? subscriptionUrl) async {
    final url = subscriptionUrl?.trim();
    if (url == null || url.isEmpty) {
      return;
    }

    final profiles = _ref.read(profilesProvider);
    Profile? existing;
    for (final profile in profiles) {
      if (profile.name == _panelProfileName) {
        existing = profile;
        break;
      }
    }

    if (existing != null) {
      await _ref.read(profilesProvider.notifier).updateProfile(
        existing.copyWith(configLink: url, type: ProfileType.subscription),
      );
      return;
    }

    await _ref.read(profilesProvider.notifier).addProfile(
      name: _panelProfileName,
      configLink: url,
      type: ProfileType.subscription,
    );
  }

  Future<void> _removePanelProfile() async {
    final profiles = _ref.read(profilesProvider);
    for (final profile in profiles) {
      if (profile.name == _panelProfileName) {
        await _ref.read(profilesProvider.notifier).removeProfile(profile.id);
      }
    }
  }
}

final panelStatsLifecycleProvider = Provider<void>((ref) {
  ref.watch(panelBootstrapProvider);
  VpnStatus? previous;
  ref.listen<AsyncValue<VpnStatus>>(vpnStatusProvider, (old, next) async {
    final status = next.value;
    if (previous == VpnStatus.started && status == VpnStatus.stopped) {
      final manager = ref.read(panelManagerProvider);
      if (!manager.isActive) {
        return;
      }
      final stats = ref.read(vpnStatsProvider).value;
      if (stats != null) {
        await manager.enqueueStats(
          PanelStatsPayload(
            sessionId: ref.read(panelSessionIdProvider),
            bytesIn: stats.downlinkTotal,
            bytesOut: stats.uplinkTotal,
            status: 'stopped',
          ),
        );
      }
      await manager.flushStats();
    }
    previous = status;
  });
});

final panelCommandsLifecycleProvider = Provider<void>((ref) {
  ref.watch(panelBootstrapProvider);
  final manager = ref.watch(panelManagerProvider);
  final commandService = ref.watch(panelCommandServiceProvider);

  if (!manager.isActive) {
    unawaited(commandService.stop());
    return;
  }

  unawaited(
    commandService.start((
      onRefreshConfig: () =>
          ref.read(panelStateProvider.notifier).handleRemoteRefreshConfig(),
      onDisconnect: () =>
          ref.read(panelStateProvider.notifier).handleRemoteDisconnect(),
      onSwitchServer: ({serverIndex, serverName}) => ref
          .read(panelStateProvider.notifier)
          .handleRemoteSwitchServer(
            serverIndex: serverIndex,
            serverName: serverName,
          ),
    )),
  );

  ref.onDispose(() {
    unawaited(commandService.stop());
  });

  ref.listen<PanelState>(panelStateProvider, (previous, next) async {
    final wasActive = previous?.settings.isConfigured ?? false;
    final isActive = next.settings.isConfigured;
    if (wasActive && !isActive) {
      await commandService.stop();
    } else if (!wasActive && isActive) {
      await commandService.start((
        onRefreshConfig: () =>
            ref.read(panelStateProvider.notifier).handleRemoteRefreshConfig(),
        onDisconnect: () =>
            ref.read(panelStateProvider.notifier).handleRemoteDisconnect(),
        onSwitchServer: ({serverIndex, serverName}) => ref
            .read(panelStateProvider.notifier)
            .handleRemoteSwitchServer(
              serverIndex: serverIndex,
              serverName: serverName,
            ),
      ));
    }
  });
});

final panelSessionIdProvider = Provider<String>((ref) {
  ref.watch(vpnStatusProvider);
  return ref.watch(vpnServiceProvider).panelSessionId;
});
