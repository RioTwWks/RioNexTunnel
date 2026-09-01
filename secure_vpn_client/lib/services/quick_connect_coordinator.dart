import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';
import 'app_log.dart';

/// Keeps the mobile quick-connect notification in sync and handles Connect taps.
final quickConnectCoordinatorProvider = Provider<QuickConnectCoordinator>((ref) {
  final coordinator = QuickConnectCoordinator(ref);
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class QuickConnectCoordinator {
  QuickConnectCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<void>? _quickConnectSubscription;
  bool _started = false;
  bool _connectInProgress = false;

  Future<void> start() async {
    if (_started || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    _started = true;

    final vpnService = _ref.read(vpnServiceProvider);
    await vpnService.initialize();
    await vpnService.v2rayBox.setQuickConnectButtonText('Connect');

    _quickConnectSubscription =
        vpnService.v2rayBox.watchQuickConnectRequests().listen((_) {
      unawaited(_handleQuickConnect());
    });

    if (await vpnService.v2rayBox.consumePendingQuickConnect()) {
      unawaited(_handleQuickConnect());
    }

    _ref.listen<Profile?>(selectedProfileProvider, (_, profile) {
      unawaited(_syncNotification());
    });
    _ref.listen<AsyncValue<VpnStatus>>(vpnStatusProvider, (_, _) {
      unawaited(_syncNotification());
    });

    await _syncNotification();
  }

  Future<void> _syncNotification() async {
    if (!_started) {
      return;
    }
    final profile = _ref.read(selectedProfileProvider);
    final status = _ref.read(vpnStatusProvider).value ?? VpnStatus.stopped;
    final visible = profile != null && status == VpnStatus.stopped;
    final vpnService = _ref.read(vpnServiceProvider);
    await vpnService.v2rayBox.updateQuickConnect(
      visible: visible,
      profileName: profile?.name ?? '',
      statusText: visible ? 'Disconnected — tap Connect' : '',
    );
  }

  Future<void> _handleQuickConnect() async {
    if (_connectInProgress) {
      return;
    }
    final profile = _ref.read(selectedProfileProvider);
    if (profile == null) {
      AppLog.info('Quick connect ignored: no profile selected');
      return;
    }
    final status = _ref.read(vpnStatusProvider).value ?? VpnStatus.stopped;
    if (status != VpnStatus.stopped) {
      return;
    }

    _connectInProgress = true;
    try {
      AppLog.info('Quick connect requested for profile=${profile.name}');
      final result = await _ref.read(vpnServiceProvider).connect(profile);
      _ref.read(engineProvider.notifier).noteActiveEngine(result.engine);
      final connectedProfile = result.profile;
      if (connectedProfile.autoSelectBestServer ||
          connectedProfile.selectedServerIndex != profile.selectedServerIndex) {
        final updated = await _ref.read(profilesProvider.notifier).selectServer(
              profileId: connectedProfile.id,
              serverIndex: connectedProfile.selectedServerIndex,
              serverName: connectedProfile.selectedServerName,
              autoSelectBestServer: connectedProfile.autoSelectBestServer,
            );
        if (updated != null) {
          await _ref.read(selectedProfileProvider.notifier).select(updated);
        }
      }
    } catch (error) {
      AppLog.error('Quick connect failed: $error');
    } finally {
      _connectInProgress = false;
      await _syncNotification();
    }
  }

  void dispose() {
    _quickConnectSubscription?.cancel();
    _quickConnectSubscription = null;
    _started = false;
  }
}
