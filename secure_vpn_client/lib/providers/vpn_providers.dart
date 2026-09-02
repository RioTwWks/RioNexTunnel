import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/credentials.dart';
import '../models/connection_detail.dart';
import '../models/engine_preference.dart';
import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../models/vpn_engine.dart';
import '../services/vpn_service.dart';

const _profilesKey = 'vpn_profiles';
const _selectedProfileIdKey = 'selected_profile_id';
const _engineKey = 'vpn_engine';
const _enginePreferenceKey = 'vpn_engine_preference';

final vpnServiceProvider = Provider<VpnService>((ref) {
  final service = VpnService();
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

final vpnStatusProvider = StreamProvider<VpnStatus>((ref) {
  final service = ref.watch(vpnServiceProvider);
  return service.watchStatus();
});

final connectionDetailProvider = StreamProvider<ConnectionDetail>((ref) {
  final service = ref.watch(vpnServiceProvider);
  return service.watchConnectionDetail();
});

final sessionCredentialsProvider = Provider<SessionCredentials?>((ref) {
  ref.watch(vpnStatusProvider);
  return ref.watch(vpnServiceProvider).sessionCredentials;
});

final vpnStatsProvider = StreamProvider<VpnStats>((ref) {
  final service = ref.watch(vpnServiceProvider);
  return service.v2rayBox.watchStats();
});

/// Live session uptime while connected (ticks every second).
final connectionUptimeProvider = StreamProvider<Duration?>((ref) async* {
  final detail = ref.watch(connectionDetailProvider);
  if (detail.value?.phase != ConnectionPhase.connected) {
    yield null;
    return;
  }
  final service = ref.watch(vpnServiceProvider);
  while (true) {
    yield service.connectionUptime;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

const _themeModeKey = 'theme_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModeKey);
    if (saved == null) {
      return;
    }
    state = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

/// User preference: Auto / Xray / sing-box.
final enginePreferenceProvider =
    StateNotifierProvider<EnginePreferenceNotifier, EnginePreference>((ref) {
      return EnginePreferenceNotifier(
        ref.watch(vpnServiceProvider),
        onActiveEngine: (engine) {
          Future.microtask(() {
            ref.read(engineProvider.notifier).noteActiveEngine(engine);
          });
        },
      );
    });

/// Currently active core engine (may change during Auto connect fallback).
final engineProvider = StateNotifierProvider<EngineNotifier, VpnEngine>((ref) {
  return EngineNotifier(ref.watch(vpnServiceProvider));
});

final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<Profile>>(
  (ref) {
    return ProfilesNotifier();
  },
);

final selectedProfileProvider =
    StateNotifierProvider<SelectedProfileNotifier, Profile?>((ref) {
      return SelectedProfileNotifier(ref);
    });

class SelectedProfileNotifier extends StateNotifier<Profile?> {
  SelectedProfileNotifier(this._ref) : super(null) {
    _ref.listen<List<Profile>>(profilesProvider, (previous, next) {
      _applyFromProfiles(next);
    }, fireImmediately: true);
    _loadSavedId();
  }

  final Ref _ref;
  String? _pendingProfileId;

  Future<void> _loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingProfileId = prefs.getString(_selectedProfileIdKey);
    _applyFromProfiles(_ref.read(profilesProvider));
  }

  void _applyFromProfiles(List<Profile> profiles) {
    final targetId = _pendingProfileId ?? state?.id;
    if (targetId == null) {
      return;
    }

    for (final profile in profiles) {
      if (profile.id == targetId) {
        state = profile;
        return;
      }
    }

    // Profiles may still be loading from SharedPreferences; do not wipe saved id.
    if (profiles.isEmpty) {
      return;
    }

    if (state?.id == targetId || _pendingProfileId == targetId) {
      state = null;
      _pendingProfileId = null;
      _clearPersisted();
    }
  }

  Future<void> select(Profile profile) async {
    state = profile;
    _pendingProfileId = profile.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProfileIdKey, profile.id);
  }

  Future<void> clear() async {
    state = null;
    _pendingProfileId = null;
    await _clearPersisted();
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedProfileIdKey);
  }
}

class EnginePreferenceNotifier extends StateNotifier<EnginePreference> {
  EnginePreferenceNotifier(
    this._vpnService, {
    void Function(VpnEngine engine)? onActiveEngine,
  }) : _onActiveEngine = onActiveEngine,
       super(EnginePreference.auto) {
    _load();
  }

  final VpnService _vpnService;
  final void Function(VpnEngine engine)? _onActiveEngine;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPref = prefs.getString(_enginePreferenceKey);
    if (savedPref != null) {
      state = EnginePreference.fromStorage(savedPref);
      _vpnService.setEnginePreference(state);
      if (!state.isAuto) {
        final engine = state == EnginePreference.singbox
            ? VpnEngine.singbox
            : VpnEngine.xray;
        await _vpnService.setEngine(engine, disconnectIfNeeded: false);
        _onActiveEngine?.call(engine);
      }
      return;
    }

    // Migrate legacy vpn_engine → fixed preference.
    final legacy = prefs.getString(_engineKey);
    if (legacy != null) {
      final engine = VpnEngine.fromCoreName(legacy);
      state = engine == VpnEngine.singbox
          ? EnginePreference.singbox
          : EnginePreference.xray;
      _vpnService.setEnginePreference(state);
      await _vpnService.setEngine(engine, disconnectIfNeeded: false);
      await prefs.setString(_enginePreferenceKey, state.storageName);
      _onActiveEngine?.call(engine);
      return;
    }

    _vpnService.setEnginePreference(EnginePreference.auto);
  }

  Future<void> setPreference(EnginePreference preference) async {
    state = preference;
    _vpnService.setEnginePreference(preference);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enginePreferenceKey, preference.storageName);

    if (!preference.isAuto) {
      final engine = preference == EnginePreference.singbox
          ? VpnEngine.singbox
          : VpnEngine.xray;
      await _vpnService.setEngine(engine);
      await prefs.setString(_engineKey, engine.coreName);
      _onActiveEngine?.call(engine);
    }
  }
}

class EngineNotifier extends StateNotifier<VpnEngine> {
  EngineNotifier(this._vpnService) : super(VpnEngine.xray) {
    state = _vpnService.engine;
  }

  final VpnService _vpnService;

  /// Updates UI after Auto connect / fallback without changing preference.
  void noteActiveEngine(VpnEngine engine) {
    state = engine;
  }

  Future<void> setEngine(VpnEngine engine) async {
    await _vpnService.setEngine(engine);
    state = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.coreName);
  }
}

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  ProfilesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) {
      return;
    }
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Profile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    state = list;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      state.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_profilesKey, encoded);
  }

  Future<void> addProfile({
    required String name,
    required String configLink,
    ProfileType type = ProfileType.link,
    bool censorshipModeEnabled = false,
    TransportPresetId? transportPreset,
    TlsFingerprint tlsFingerprint = TlsFingerprint.firefox,
    bool muxEnabled = false,
    int muxConcurrency = 8,
    bool ruDirectRouting = false,
  }) async {
    final profile = Profile(
      id: const Uuid().v4(),
      name: name,
      configLink: configLink,
      type: type,
      autoSelectBestServer: type == ProfileType.subscription,
      censorshipModeEnabled: censorshipModeEnabled,
      transportPreset: transportPreset,
      tlsFingerprint: tlsFingerprint,
      muxEnabled: muxEnabled,
      muxConcurrency: muxConcurrency,
      ruDirectRouting: ruDirectRouting,
    );
    state = [...state, profile];
    await _persist();
  }

  Future<void> updateProfile(Profile profile) async {
    final index = state.indexWhere((p) => p.id == profile.id);
    if (index < 0) {
      return;
    }
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
    ];
    await _persist();
  }

  Future<Profile?> selectServer({
    required String profileId,
    required int serverIndex,
    String? serverName,
    bool autoSelectBestServer = false,
  }) async {
    final index = state.indexWhere((profile) => profile.id == profileId);
    if (index < 0) {
      return null;
    }
    final updated = state[index].copyWith(
      selectedServerIndex: serverIndex,
      selectedServerName: serverName,
      autoSelectBestServer: autoSelectBestServer,
    );
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];
    await _persist();
    return updated;
  }

  Future<void> removeProfile(String id) async {
    state = state.where((profile) => profile.id != id).toList();
    await _persist();
  }
}
