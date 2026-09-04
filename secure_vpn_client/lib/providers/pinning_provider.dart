import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pinning_config.dart';

const _pinningConfigKey = 'subscription_pinning_config';

final pinningProvider =
    StateNotifierProvider<PinningNotifier, PinningConfig>((ref) {
  return PinningNotifier();
});

class PinningNotifier extends StateNotifier<PinningConfig> {
  PinningNotifier() : super(PinningConfig.disabled) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PinningConfig.fromStorage(prefs.getString(_pinningConfigKey));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinningConfigKey, state.toStorageJson());
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _persist();
  }

  Future<void> addPin({
    required String host,
    required String pin,
  }) async {
    final normalizedHost = host.trim().toLowerCase();
    final normalizedPin = SubscriptionSpki.normalizePin(pin);
    if (normalizedHost.isEmpty || !SubscriptionSpki.isValidPinFormat(normalizedPin)) {
      return;
    }
    final updated = Map<String, List<String>>.from(state.pinsByHost);
    final existing = List<String>.from(updated[normalizedHost] ?? const []);
    if (!existing.contains(normalizedPin)) {
      existing.add(normalizedPin);
    }
    updated[normalizedHost] = existing;
    state = state.copyWith(pinsByHost: updated);
    await _persist();
  }

  Future<void> removePin({
    required String host,
    required String pin,
  }) async {
    final normalizedHost = host.trim().toLowerCase();
    final normalizedPin = SubscriptionSpki.normalizePin(pin);
    final existing = state.pinsByHost[normalizedHost];
    if (existing == null) {
      return;
    }
    final updatedPins = existing
        .where((value) => value != normalizedPin)
        .toList(growable: false);
    final updated = Map<String, List<String>>.from(state.pinsByHost);
    if (updatedPins.isEmpty) {
      updated.remove(normalizedHost);
    } else {
      updated[normalizedHost] = updatedPins;
    }
    state = state.copyWith(pinsByHost: updated);
    await _persist();
  }

  Future<void> removeHost(String host) async {
    final normalizedHost = host.trim().toLowerCase();
    if (!state.pinsByHost.containsKey(normalizedHost)) {
      return;
    }
    final updated = Map<String, List<String>>.from(state.pinsByHost)
      ..remove(normalizedHost);
    state = state.copyWith(pinsByHost: updated);
    await _persist();
  }
}
