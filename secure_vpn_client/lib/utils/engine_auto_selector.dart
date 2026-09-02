import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/engine_preference.dart';
import '../models/profile.dart';
import '../models/vpn_engine.dart';
import 'config_parser.dart';
import 'link_config_builder.dart';

/// Result of resolving which core engine(s) to try for a profile.
class EngineResolution {
  const EngineResolution({required this.attemptOrder, required this.reason});

  /// Engines to try in order (primary first, then connect fallbacks).
  final List<VpnEngine> attemptOrder;

  /// Human-readable explanation for logs / Settings subtitle.
  final String reason;

  VpnEngine get preferred => attemptOrder.first;
}

/// Picks xray vs sing-box from availability, subscription format, and geo needs.
class EngineAutoSelector {
  /// Default preference order when scores are equal.
  static const defaultOrder = [VpnEngine.xray, VpnEngine.singbox];

  /// Returns engines that appear present on this device.
  static Future<Set<VpnEngine>> availableEngines(V2rayBox box) async {
    if (kIsWeb) {
      return const {};
    }

    try {
      final info = await box.getCoreInfo();
      final xray = _truthy(info['xray_available']);
      final singbox = _truthy(info['singbox_available']);
      if (info.containsKey('xray_available') ||
          info.containsKey('singbox_available')) {
        return {if (xray) VpnEngine.xray, if (singbox) VpnEngine.singbox};
      }
    } catch (_) {
      // Fall through to filesystem / platform heuristics.
    }

    return _heuristicAvailableEngines();
  }

  static Future<Set<VpnEngine>> _heuristicAvailableEngines() async {
    if (Platform.isIOS) {
      return {VpnEngine.singbox};
    }
    if (Platform.isAndroid) {
      // Xray ships as AAR; sing-box needs libsingbox.so (often missing).
      return {VpnEngine.xray};
    }
    if (Platform.isMacOS || Platform.isWindows) {
      return {VpnEngine.xray, VpnEngine.singbox};
    }
    if (Platform.isLinux) {
      final available = <VpnEngine>{};
      if (await _linuxBinaryExists('xray')) {
        available.add(VpnEngine.xray);
      }
      if (await _linuxBinaryExists('sing-box')) {
        available.add(VpnEngine.singbox);
      }
      if (available.isEmpty) {
        // Still allow attempts — Start() will surface a clear error.
        return {VpnEngine.xray, VpnEngine.singbox};
      }
      return available;
    }
    return {VpnEngine.xray, VpnEngine.singbox};
  }

  static Future<bool> _linuxBinaryExists(String binaryName) async {
    final home = Platform.environment['HOME'] ?? '';
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      if (Platform.environment['V2RAY_BOX_XRAY_PATH'] != null &&
          binaryName == 'xray')
        Platform.environment['V2RAY_BOX_XRAY_PATH']!,
      if (Platform.environment['V2RAY_BOX_SINGBOX_PATH'] != null &&
          binaryName == 'sing-box')
        Platform.environment['V2RAY_BOX_SINGBOX_PATH']!,
      '$exeDir/lib/resources/$binaryName',
      '$exeDir/resources/$binaryName',
      '$exeDir/$binaryName',
      if (home.isNotEmpty) '$home/.local/share/v2ray_box/cores/$binaryName',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> xrayGeoAssetsPresent() async {
    if (kIsWeb) {
      return false;
    }
    if (Platform.isAndroid) {
      // Packaged under assets/xray and copied at runtime by XrayBridge.
      return true;
    }
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return true;
    }
    final home = Platform.environment['HOME'] ?? '';
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dirs = <String>[
      '$exeDir/lib/resources',
      '$exeDir/resources',
      if (home.isNotEmpty) '$home/.local/share/v2ray_box/assets',
    ];
    for (final dir in dirs) {
      final geoip = File('$dir/geoip.dat');
      final geosite = File('$dir/geosite.dat');
      if (await geoip.exists() && await geosite.exists()) {
        return true;
      }
    }
    // Also accept files next to cores in bundle.
    for (final dir in dirs) {
      if (await Directory(dir).exists()) {
        final entries = await Directory(dir).list().toList();
        final names = entries.map((e) => e.uri.pathSegments.last).toSet();
        if (names.contains('geoip.dat') && names.contains('geosite.dat')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Builds attempt order for [preference] and [profile].
  static Future<EngineResolution> resolve({
    required Profile profile,
    required V2rayBox box,
    required EnginePreference preference,
  }) async {
    final available = await availableEngines(box);
    if (available.isEmpty) {
      throw StateError('No VPN core engines are available on this device');
    }

    if (preference == EnginePreference.xray ||
        preference == EnginePreference.singbox) {
      final fixed = preference == EnginePreference.xray
          ? VpnEngine.xray
          : VpnEngine.singbox;
      if (!available.contains(fixed)) {
        throw StateError(
          '${fixed.coreName} is not available on this device. '
          'Install cores or switch engine preference.',
        );
      }
      return EngineResolution(
        attemptOrder: [fixed],
        reason: 'Manual preference: ${fixed.coreName}',
      );
    }

    // Auto: availability → format → geo demotion → default order + fallback.
    final order = await _autoOrder(profile, available);
    return EngineResolution(
      attemptOrder: order,
      reason: 'Auto: try ${order.map((e) => e.coreName).join(' → ')}',
    );
  }

  static Future<List<VpnEngine>> _autoOrder(
    Profile profile,
    Set<VpnEngine> available,
  ) async {
    final base = defaultOrder.where(available.contains).toList();
    if (base.isEmpty) {
      return available.toList();
    }
    if (base.length == 1) {
      return base;
    }

    if (profile.type == ProfileType.link) {
      if (LinkConfigBuilder.requiresSingbox(profile.configLink) &&
          available.contains(VpnEngine.singbox)) {
        return [
          VpnEngine.singbox,
          ...base.where((engine) => engine != VpnEngine.singbox),
        ];
      }
      return base;
    }

    // Subscription: score by which UA yields a parseable server list.
    final scores = <VpnEngine, int>{};
    String? xrayBody;
    for (final engine in base) {
      try {
        final body = await ConfigParser.fetchSubscriptionBody(
          profile.configLink,
          engine: engine,
        );
        if (engine == VpnEngine.xray) {
          xrayBody = body;
        }
        final servers = ConfigParser.listSubscriptionServers(body);
        var score = servers.length;
        final singboxOnly = servers.any(
          (server) => LinkConfigBuilder.requiresSingbox(server.content),
        );
        if (singboxOnly) {
          if (engine == VpnEngine.singbox) {
            score += 1000;
          } else if (servers.every(
            (server) => LinkConfigBuilder.requiresSingbox(server.content),
          )) {
            // Entire list needs sing-box — demote xray.
            score = 0;
          }
        }
        scores[engine] = score;
      } catch (_) {
        scores[engine] = -1;
      }
    }

    final geoOk = await xrayGeoAssetsPresent();
    if (!geoOk &&
        xrayBody != null &&
        needsXrayGeo(xrayBody) &&
        scores.containsKey(VpnEngine.xray) &&
        (scores[VpnEngine.xray] ?? -1) > 0) {
      // Demote xray when geosite/geoip rules are present but assets missing.
      scores[VpnEngine.xray] = 0;
    }

    final working = base.where((engine) => (scores[engine] ?? -1) > 0).toList()
      ..sort((a, b) {
        final byScore = (scores[b] ?? -1).compareTo(scores[a] ?? -1);
        if (byScore != 0) {
          return byScore;
        }
        return defaultOrder.indexOf(a).compareTo(defaultOrder.indexOf(b));
      });

    if (working.isEmpty) {
      return base;
    }

    final rest = base.where((engine) => !working.contains(engine));
    return [...working, ...rest];
  }

  static bool needsXrayGeo(String body) {
    final lower = body.toLowerCase();
    return lower.contains('geosite:') || lower.contains('geoip:');
  }

  static bool _truthy(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }
}
