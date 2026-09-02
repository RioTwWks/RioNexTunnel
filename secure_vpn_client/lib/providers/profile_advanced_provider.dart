import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ruDirectDefaultKey = 'censorship_ru_direct_default';

final ruDirectRoutingDefaultProvider =
    StateNotifierProvider<RuDirectDefaultNotifier, bool>((ref) {
  return RuDirectDefaultNotifier();
});

class RuDirectDefaultNotifier extends StateNotifier<bool> {
  RuDirectDefaultNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_ruDirectDefaultKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ruDirectDefaultKey, enabled);
  }
}
