import 'dart:convert';

import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../models/vpn_engine.dart';

/// Options passed when building config from a share link.
class LinkBuildOptions {
  const LinkBuildOptions({
    this.fingerprint = TlsFingerprint.firefox,
    this.muxEnabled = false,
    this.muxConcurrency = 8,
  });

  final TlsFingerprint fingerprint;
  final bool muxEnabled;
  final int muxConcurrency;

  factory LinkBuildOptions.fromProfile(Profile profile) {
    return LinkBuildOptions(
      fingerprint: profile.tlsFingerprint,
      muxEnabled: profile.muxEnabled,
      muxConcurrency: profile.muxConcurrency,
    );
  }
}

/// Applies profile-level censorship settings to resolved JSON config.
class ConfigEnhancer {
  ConfigEnhancer._();

  static String applyProfileSettings(
    String jsonConfig,
    Profile profile,
    VpnEngine engine,
  ) {
    if (!profile.censorshipModeEnabled &&
        !profile.muxEnabled &&
        !profile.ruDirectRouting) {
      return jsonConfig;
    }

    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      return jsonConfig;
    }
    final config = Map<String, dynamic>.from(decoded);

    if (profile.censorshipModeEnabled || profile.muxEnabled) {
      _applyFingerprintAndMux(config, profile, engine);
    }
    if (profile.ruDirectRouting) {
      _applyRuDirectRouting(config, engine);
    }

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static void _applyFingerprintAndMux(
    Map<String, dynamic> config,
    Profile profile,
    VpnEngine engine,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return;
    }

    for (var i = 0; i < outbounds.length; i++) {
      final raw = outbounds[i];
      if (raw is! Map) {
        continue;
      }
      final outbound = Map<String, dynamic>.from(raw);
      if (!_isProxyOutbound(outbound)) {
        continue;
      }

      if (engine == VpnEngine.xray) {
        _applyXrayFingerprint(outbound, profile.tlsFingerprint);
        if (profile.muxEnabled) {
          outbound['mux'] = {
            'enabled': true,
            'concurrency': profile.muxConcurrency,
          };
        }
      } else {
        _applySingboxFingerprint(outbound, profile.tlsFingerprint);
        if (profile.muxEnabled) {
          outbound['multiplex'] = {
            'enabled': true,
            'max_connections': profile.muxConcurrency,
          };
        }
      }
      outbounds[i] = outbound;
      break;
    }
    config['outbounds'] = outbounds;
  }

  static bool _isProxyOutbound(Map<String, dynamic> outbound) {
    final protocol = outbound['protocol']?.toString();
    final type = outbound['type']?.toString();
    return protocol == 'vless' ||
        protocol == 'vmess' ||
        protocol == 'trojan' ||
        type == 'vless' ||
        type == 'vmess' ||
        type == 'trojan';
  }

  static void _applyXrayFingerprint(
    Map<String, dynamic> outbound,
    TlsFingerprint fingerprint,
  ) {
    final stream = outbound['streamSettings'];
    if (stream is! Map) {
      return;
    }
    final streamMap = Map<String, dynamic>.from(stream);
    final security = streamMap['security']?.toString();
    if (security == 'reality') {
      final reality = streamMap['realitySettings'];
      final realityMap = reality is Map
          ? Map<String, dynamic>.from(reality)
          : <String, dynamic>{};
      realityMap['fingerprint'] = fingerprint.wireValue;
      streamMap['realitySettings'] = realityMap;
    } else if (security == 'tls') {
      final tls = streamMap['tlsSettings'];
      final tlsMap = tls is Map
          ? Map<String, dynamic>.from(tls)
          : <String, dynamic>{};
      tlsMap['fingerprint'] = fingerprint.wireValue;
      streamMap['tlsSettings'] = tlsMap;
    }
    outbound['streamSettings'] = streamMap;
  }

  static void _applySingboxFingerprint(
    Map<String, dynamic> outbound,
    TlsFingerprint fingerprint,
  ) {
    final tls = outbound['tls'];
    if (tls is! Map) {
      return;
    }
    final tlsMap = Map<String, dynamic>.from(tls);
    tlsMap['utls'] = {
      'enabled': true,
      'fingerprint': fingerprint.wireValue,
    };
    outbound['tls'] = tlsMap;
  }

  static void _applyRuDirectRouting(
    Map<String, dynamic> config,
    VpnEngine engine,
  ) {
    if (engine == VpnEngine.xray) {
      final routing = config['routing'];
      final routingMap = routing is Map
          ? Map<String, dynamic>.from(routing)
          : <String, dynamic>{'domainStrategy': 'AsIs'};
      final rules = List<dynamic>.from(
        routingMap['rules'] as List<dynamic>? ?? const [],
      );
      rules.insertAll(0, [
        {
          'type': 'field',
          'domain': ['geosite:ru'],
          'outboundTag': 'direct',
        },
        {
          'type': 'field',
          'ip': ['geoip:ru'],
          'outboundTag': 'direct',
        },
      ]);
      routingMap['rules'] = rules;
      config['routing'] = routingMap;
      return;
    }

    final route = config['route'];
    final routeMap = route is Map
        ? Map<String, dynamic>.from(route)
        : <String, dynamic>{'final': 'proxy'};
    final rules = List<dynamic>.from(
      routeMap['rules'] as List<dynamic>? ?? const [],
    );
    rules.insertAll(0, [
      {'geosite': ['ru'], 'outbound': 'direct'},
      {'geoip': ['ru'], 'outbound': 'direct'},
    ]);
    routeMap['rules'] = rules;
    routeMap.putIfAbsent('final', () => 'proxy');
    config['route'] = routeMap;
  }
}
