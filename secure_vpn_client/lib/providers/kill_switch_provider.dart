import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/kill_switch_mode.dart';
import '../services/kill_switch_service.dart';

final killSwitchServiceProvider = Provider<KillSwitchService>((ref) {
  return KillSwitchService(V2rayBox());
});

final killSwitchModeProvider =
    StateNotifierProvider<KillSwitchModeNotifier, KillSwitchMode>((ref) {
      return KillSwitchModeNotifier(ref.watch(killSwitchServiceProvider));
    });

class KillSwitchModeNotifier extends StateNotifier<KillSwitchMode> {
  KillSwitchModeNotifier(this._service) : super(KillSwitchMode.off) {
    _load();
  }

  final KillSwitchService _service;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = KillSwitchMode.fromStorage(
      prefs.getString(KillSwitchMode.storageKey),
    );
    state = saved;
    await _service.loadMode(saved);
  }

  Future<void> setMode(KillSwitchMode mode) async {
    if (mode == KillSwitchMode.adaptive) {
      return;
    }
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KillSwitchMode.storageKey, mode.storageName);
    await _service.loadMode(mode);
  }
}
