import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/split_tunnel_settings.dart';
import '../services/split_tunnel_service.dart';
import 'vpn_providers.dart';

/// User-facing split tunneling state (Android VPN mode).
class PerAppProxySettings {
  const PerAppProxySettings({
    this.mode = SplitTunnelMode.off,
    this.selectedPackages = const {},
    this.loading = true,
  });

  final SplitTunnelMode mode;
  final Set<String> selectedPackages;
  final bool loading;

  bool get isEnabled => mode.isEnabled;
  bool get isIncludeMode => mode == SplitTunnelMode.include;
  bool get isExcludeMode => mode == SplitTunnelMode.exclude;

  /// Backwards-compatible alias for exclude-only UI/tests.
  bool get excludeEnabled => isExcludeMode;

  Set<String> get excludedPackages =>
      isExcludeMode ? selectedPackages : const {};

  Set<String> get includedPackages =>
      isIncludeMode ? selectedPackages : const {};

  SplitTunnelSettings toSettings() => SplitTunnelSettings(
    mode: mode,
    selectedPackages: selectedPackages,
  );

  PerAppProxySettings copyWith({
    SplitTunnelMode? mode,
    Set<String>? selectedPackages,
    bool? loading,
  }) {
    return PerAppProxySettings(
      mode: mode ?? this.mode,
      selectedPackages: selectedPackages ?? this.selectedPackages,
      loading: loading ?? this.loading,
    );
  }
}

final splitTunnelServiceProvider = Provider<SplitTunnelService>((ref) {
  return SplitTunnelService(ref.watch(vpnServiceProvider).v2rayBox);
});

final perAppProxyProvider =
    StateNotifierProvider<PerAppProxyNotifier, PerAppProxySettings>((ref) {
      return PerAppProxyNotifier(ref.watch(splitTunnelServiceProvider));
    });

class PerAppProxyNotifier extends StateNotifier<PerAppProxySettings> {
  PerAppProxyNotifier(this._service) : super(const PerAppProxySettings()) {
    if (!kIsWeb && Platform.isAndroid) {
      _load();
    } else {
      state = state.copyWith(loading: false);
    }
  }

  final SplitTunnelService _service;

  Future<void> _load() async {
    try {
      final settings = await _service.load();
      state = PerAppProxySettings(
        mode: settings.mode,
        selectedPackages: settings.selectedPackages,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> setMode(SplitTunnelMode mode) async {
    await _service.setMode(mode);
    state = state.copyWith(mode: mode);
  }

  Future<void> setExcludeEnabled(bool enabled) async {
    await setMode(enabled ? SplitTunnelMode.exclude : SplitTunnelMode.off);
  }

  Future<void> setSelectedPackages(
    Set<String> packages, {
    SplitTunnelMode? mode,
  }) async {
    final effectiveMode = mode ?? state.mode;
    if (!effectiveMode.isEnabled) {
      return;
    }
    await _service.setSelectedPackages(packages, effectiveMode);
    state = state.copyWith(
      mode: effectiveMode,
      selectedPackages: packages,
    );
  }

  Future<void> setExcludedPackages(Set<String> packages) {
    return setSelectedPackages(packages, mode: SplitTunnelMode.exclude);
  }

  Future<void> toggleApp(
    String packageName, {
    required bool selected,
    SplitTunnelMode? mode,
  }) {
    final effectiveMode = mode ?? state.mode;
    final updated = Set<String>.from(state.selectedPackages);
    if (selected) {
      updated.add(packageName);
    } else {
      updated.remove(packageName);
    }
    return setSelectedPackages(updated, mode: effectiveMode);
  }

  Future<void> toggleExcludedApp(String packageName, {required bool excluded}) {
    return toggleApp(
      packageName,
      selected: excluded,
      mode: SplitTunnelMode.exclude,
    );
  }
}
