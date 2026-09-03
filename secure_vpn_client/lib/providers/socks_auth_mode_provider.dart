import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/socks_auth_mode.dart';

const _socksAuthModeKey = 'socks_auth_mode';

final socksAuthModeProvider =
    StateNotifierProvider<SocksAuthModeNotifier, SocksAuthMode>((ref) {
  return SocksAuthModeNotifier();
});

class SocksAuthModeNotifier extends StateNotifier<SocksAuthMode> {
  SocksAuthModeNotifier() : super(SocksAuthMode.randomPerSession) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SocksAuthMode.fromStorage(prefs.getString(_socksAuthModeKey));
  }

  Future<void> setMode(SocksAuthMode mode) async {
    if (mode == SocksAuthMode.disableInjection) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_socksAuthModeKey, mode.storageName);
  }
}
