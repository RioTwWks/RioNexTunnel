import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/kill_switch_mode.dart';
import '../services/app_log.dart';

class KillSwitchService {
  KillSwitchService(this._v2rayBox);

  final V2rayBox _v2rayBox;

  KillSwitchMode _mode = KillSwitchMode.off;
  bool _armed = false;
  bool _engaged = false;
  Timer? _coreWatchTimer;
  int _socksPort = 1080;

  bool get isArmed => _armed;
  bool get isEngaged => _engaged;

  bool get _isDesktopProxy {
    return !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  }

  Future<void> loadMode(KillSwitchMode mode) async {
    _mode = mode;
    await _v2rayBox.setKillSwitchMode(mode.storageName);
  }

  Future<void> onSessionStart({required int socksPort}) async {
    _socksPort = socksPort;
    if (!_mode.isStrict) {
      return;
    }
    AppLog.info('Kill switch: arming strict mode');
    final ok = await _v2rayBox.armKillSwitch(socksPort: socksPort);
    _armed = ok;
    if (_isDesktopProxy) {
      _startCoreWatch();
    }
  }

  Future<void> onTunnelDown() async {
    if (!_mode.isStrict || _engaged) {
      return;
    }
    AppLog.info('Kill switch: engaging strict block');
    final ok = await _v2rayBox.engageKillSwitch();
    _engaged = ok;
  }

  Future<void> onTunnelRestored() async {
    if (!_mode.isStrict) {
      return;
    }
    if (_engaged) {
      await _v2rayBox.disengageKillSwitch();
      _engaged = false;
    }
    if (_armed) {
      await _v2rayBox.armKillSwitch(socksPort: _socksPort);
    }
  }

  Future<void> onSessionEnd({required bool userInitiated}) async {
    _stopCoreWatch();
    if (!_mode.isStrict && !_armed && !_engaged) {
      return;
    }
    await _v2rayBox.releaseKillSwitch();
    _armed = false;
    _engaged = false;
  }

  void _startCoreWatch() {
    _coreWatchTimer?.cancel();
    _coreWatchTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_checkCoreHealth());
    });
  }

  void _stopCoreWatch() {
    _coreWatchTimer?.cancel();
    _coreWatchTimer = null;
  }

  Future<void> _checkCoreHealth() async {
    if (!_armed || _engaged || !_mode.isStrict) {
      return;
    }
    final running = await _v2rayBox.isCoreRunning();
    if (!running) {
      AppLog.error('Kill switch: core exited unexpectedly');
      await onTunnelDown();
    }
  }
}
