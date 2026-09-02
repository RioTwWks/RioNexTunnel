import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import 'vpn_providers.dart';

/// User-facing split tunneling state (Android VPN mode only).
class PerAppProxySettings {
  const PerAppProxySettings({
    this.mode = PerAppProxyMode.off,
    this.excludedPackages = const {},
    this.loading = true,
  });

  final PerAppProxyMode mode;
  final Set<String> excludedPackages;
  final bool loading;

  bool get excludeEnabled => mode == PerAppProxyMode.exclude;

  PerAppProxySettings copyWith({
    PerAppProxyMode? mode,
    Set<String>? excludedPackages,
    bool? loading,
  }) {
    return PerAppProxySettings(
      mode: mode ?? this.mode,
      excludedPackages: excludedPackages ?? this.excludedPackages,
      loading: loading ?? this.loading,
    );
  }
}

final perAppProxyProvider =
    StateNotifierProvider<PerAppProxyNotifier, PerAppProxySettings>((ref) {
      return PerAppProxyNotifier(ref.watch(vpnServiceProvider).v2rayBox);
    });

class PerAppProxyNotifier extends StateNotifier<PerAppProxySettings> {
  PerAppProxyNotifier(this._v2rayBox) : super(const PerAppProxySettings()) {
    if (!kIsWeb && Platform.isAndroid) {
      _load();
    } else {
      state = state.copyWith(loading: false);
    }
  }

  final V2rayBox _v2rayBox;

  Future<void> _load() async {
    try {
      final mode = await _v2rayBox.getPerAppProxyMode();
      var excluded = <String>{};
      if (mode == PerAppProxyMode.exclude) {
        excluded = (await _v2rayBox.getPerAppProxyList(
          PerAppProxyMode.exclude,
        )).toSet();
      }
      state = PerAppProxySettings(
        mode: mode,
        excludedPackages: excluded,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> setExcludeEnabled(bool enabled) async {
    final mode = enabled ? PerAppProxyMode.exclude : PerAppProxyMode.off;
    await _v2rayBox.setPerAppProxyMode(mode);
    state = state.copyWith(mode: mode);
  }

  Future<void> setExcludedPackages(Set<String> packages) async {
    await _v2rayBox.setPerAppProxyMode(PerAppProxyMode.exclude);
    await _v2rayBox.setPerAppProxyList(
      packages.toList(),
      PerAppProxyMode.exclude,
    );
    state = state.copyWith(
      mode: PerAppProxyMode.exclude,
      excludedPackages: packages,
    );
  }

  Future<void> toggleExcludedApp(String packageName, {required bool excluded}) {
    final updated = Set<String>.from(state.excludedPackages);
    if (excluded) {
      updated.add(packageName);
    } else {
      updated.remove(packageName);
    }
    return setExcludedPackages(updated);
  }
}
