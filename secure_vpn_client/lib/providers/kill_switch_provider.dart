import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2ray_box/v2ray_box.dart';
import '../models/kill_switch_mode.dart';
import '../services/kill_switch_service.dart';

final killSwitchServiceProvider = Provider<KillSwitchService>((ref) => KillSwitchService(V2rayBox()));
final killSwitchModeProvider = StateNotifierProvider<KillSwitchModeNotifier, KillSwitchMode>((ref) => KillSwitchModeNotifier(ref.watch(killSwitchServiceProvider)));

class KillSwitchModeNotifier extends StateNotifier<KillSwitchMode> {
  KillSwitchModeNotifier(this._service) : super(KillSwitchMode.off) { _load(); }
  final KillSwitchService _service;
  int _loadGeneration = 0;
  Future<void> _load() async {
    final g = ++_loadGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (g != _loadGeneration) return;
    state = KillSwitchMode.fromStorage(prefs.getString(KillSwitchMode.storageKey));
    await _service.loadMode(state);
  }
  Future<void> setMode(KillSwitchMode mode) async {
    _loadGeneration++;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KillSwitchMode.storageKey, mode.storageName);
    await _service.loadMode(mode);
  }
}
