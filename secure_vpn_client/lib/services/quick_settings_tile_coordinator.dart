import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';
import 'app_log.dart';

/// Android Quick Settings tile: sync state and handle connect/disconnect taps.
final quickSettingsTileCoordinatorProvider =
    Provider<QuickSettingsTileCoordinator>((ref) {
  final coordinator = QuickSettingsTileCoordinator(ref);
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class QuickSettingsTileCoordinator {
  QuickSettingsTileCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tileSubscription;
  bool _started = false;
  bool _actionInProgress = false;

  Future<void> start() async {
    if (_started || kIsWeb || !Platform.isAndroid) {
      return;
    }
    _started = true;

    final vpnService = _ref.read(vpnServiceProvider);
    await vpnService.initialize();

    _tileSubscription = vpnService.v2rayBox
        .watchQuickSettingsTileRequests()
        .listen(_handleTileAction);

    final pending = await vpnService.v2rayBox.consumePendingTileAction();
    if (pending != null) {
      unawaited(_handleTileAction(pending));
    }

    _ref.listen<Profile?>(selectedProfileProvider, (_, _) {
      unawaited(_syncTile());
    });
    _ref.listen<AsyncValue<VpnStatus>>(vpnStatusProvider, (_, _) {
      unawaited(_syncTile());
    });

    // Sync tile after profiles finish loading from SharedPreferences.
    _ref.listen<List<Profile>>(profilesProvider, (_, _) {
      unawaited(_syncTile());
    });

    await _syncTile();
  }

  Future<void> _syncTile() async {
    if (!_started) {
      return;
    }
    final profile = _ref.read(selectedProfileProvider);
    await _ref.read(vpnServiceProvider).v2rayBox.syncQuickSettingsTile(
          hasProfile: profile != null,
          profileName: profile?.name ?? '',
        );
  }

  Future<void> _handleTileAction(String action) async {
    if (_actionInProgress) {
      return;
    }

    // Profiles may still be loading when app opens from a tile tap.
    if (action == 'connect') {
      await _waitForSelectedProfile();
    }

    final status = _ref.read(vpnStatusProvider).value ?? VpnStatus.stopped;
    if (action == 'disconnect') {
      if (status == VpnStatus.stopped) {
        return;
      }
      _actionInProgress = true;
      try {
        AppLog.info('Quick Settings tile: disconnect');
        await _ref.read(vpnServiceProvider).disconnect();
      } catch (error) {
        AppLog.error('Quick Settings tile disconnect failed: $error');
      } finally {
        _actionInProgress = false;
        await _syncTile();
      }
      return;
    }

    final profile = _ref.read(selectedProfileProvider);
    if (profile == null) {
      AppLog.info('Quick Settings tile connect ignored: no profile');
      return;
    }
    if (status != VpnStatus.stopped) {
      return;
    }

    _actionInProgress = true;
    try {
      AppLog.info('Quick Settings tile: connect profile=${profile.name}');
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
      AppLog.error('Quick Settings tile connect failed: $error');
    } finally {
      _actionInProgress = false;
      await _syncTile();
    }
  }

  Future<void> _waitForSelectedProfile() async {
    if (_ref.read(selectedProfileProvider) != null) {
      return;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_ref.read(selectedProfileProvider) != null) {
        return;
      }
      if (_ref.read(profilesProvider).isNotEmpty) {
        return;
      }
    }
  }

  void dispose() {
    _tileSubscription?.cancel();
    _tileSubscription = null;
    _started = false;
  }
}
