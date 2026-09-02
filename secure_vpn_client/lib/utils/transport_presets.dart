import 'dart:convert';

import '../models/transport_preset.dart';
import 'link_config_builder.dart';

/// Transport preset detection and link-parameter helpers for censorship UX.
class TransportPresets {
  TransportPresets._();

  static const defaultFingerprint = TlsFingerprint.firefox;
  static const defaultMuxConcurrency = 8;
  static const defaultXhttpMode = 'stream-one';

  static const wizardOrder = [
    TransportPresetId.xhttpReality,
    TransportPresetId.reality,
    TransportPresetId.wsTls,
    TransportPresetId.grpcTls,
    TransportPresetId.httpUpgradeTls,
    TransportPresetId.plainTls,
  ];

  static DetectedTransport detectFromContent(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) {
      return _detectFromJson(trimmed);
    }
    if (LinkConfigBuilder.isConfigLink(trimmed)) {
      return _detectFromLink(trimmed);
    }
    return const DetectedTransport(preset: TransportPresetId.plainTls);
  }

  static DetectedTransport _detectFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;
      final type = (params['type'] ?? 'tcp').toLowerCase();
      final security = (params['security'] ?? '').toLowerCase();
      return DetectedTransport(
        preset: _presetFromParams(type: type, security: security),
        security: security.isEmpty ? null : security,
        network: type == 'tcp' ? null : type,
        fingerprint: params['fp'],
        xhttpMode: params['mode'],
      );
    } catch (_) {
      return const DetectedTransport(preset: TransportPresetId.plainTls);
    }
  }

  static DetectedTransport _detectFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        return const DetectedTransport(preset: TransportPresetId.plainTls);
      }
      final outbound = _firstProxyOutbound(Map<String, dynamic>.from(decoded));
      if (outbound == null) {
        return const DetectedTransport(preset: TransportPresetId.plainTls);
      }
      if (outbound.containsKey('type')) {
        return _detectFromSingboxOutbound(outbound);
      }
      return _detectFromXrayOutbound(outbound);
    } catch (_) {
      return const DetectedTransport(preset: TransportPresetId.plainTls);
    }
  }

  static DetectedTransport _detectFromXrayOutbound(Map<String, dynamic> outbound) {
    final stream = outbound['streamSettings'];
    if (stream is! Map) {
      return const DetectedTransport(preset: TransportPresetId.plainTls);
    }
    final network = stream['network']?.toString().toLowerCase() ?? 'tcp';
    final security = stream['security']?.toString().toLowerCase() ?? '';
    String? fp;
    String? mode;
    if (security == 'reality') {
      final reality = stream['realitySettings'];
      if (reality is Map) {
        fp = reality['fingerprint']?.toString();
      }
    } else if (security == 'tls') {
      final tls = stream['tlsSettings'];
      if (tls is Map) {
        fp = tls['fingerprint']?.toString();
      }
    }
    if (network == 'xhttp') {
      final xhttp = stream['xhttpSettings'];
      if (xhttp is Map) {
        mode = xhttp['mode']?.toString();
      }
    }
    final mux = outbound['mux'];
    return DetectedTransport(
      preset: _presetFromParams(type: network, security: security),
      security: security.isEmpty ? null : security,
      network: network == 'tcp' ? null : network,
      fingerprint: fp,
      hasMux: mux is Map && mux['enabled'] == true,
      xhttpMode: mode,
    );
  }

  static DetectedTransport _detectFromSingboxOutbound(
    Map<String, dynamic> outbound,
  ) {
    final tls = outbound['tls'];
    String security = '';
    String? fp;
    if (tls is Map) {
      if (tls['reality'] is Map && (tls['reality'] as Map)['enabled'] == true) {
        security = 'reality';
      } else if (tls['enabled'] == true) {
        security = 'tls';
      }
      final utls = tls['utls'];
      if (utls is Map) {
        fp = utls['fingerprint']?.toString();
      }
    }
    String network = 'tcp';
    final transport = outbound['transport'];
    if (transport is Map) {
      network = transport['type']?.toString().toLowerCase() ?? 'tcp';
    }
    return DetectedTransport(
      preset: _presetFromParams(type: network, security: security),
      security: security.isEmpty ? null : security,
      network: network == 'tcp' ? null : network,
      fingerprint: fp,
    );
  }

  static TransportPresetId _presetFromParams({
    required String type,
    required String security,
  }) {
    if (type == 'xhttp' && security == 'reality') {
      return TransportPresetId.xhttpReality;
    }
    if (security == 'reality') {
      return TransportPresetId.reality;
    }
    return switch (type) {
      'ws' => TransportPresetId.wsTls,
      'grpc' => TransportPresetId.grpcTls,
      'httpupgrade' => TransportPresetId.httpUpgradeTls,
      'xhttp' => TransportPresetId.xhttpReality,
      _ => TransportPresetId.plainTls,
    };
  }

  static Map<String, dynamic>? _firstProxyOutbound(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return null;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final outbound = Map<String, dynamic>.from(raw);
      final protocol = outbound['protocol']?.toString();
      final type = outbound['type']?.toString();
      if (protocol == 'vless' ||
          protocol == 'vmess' ||
          protocol == 'trojan' ||
          type == 'vless' ||
          type == 'vmess' ||
          type == 'trojan') {
        return outbound;
      }
    }
    return null;
  }

  static TransportPresetId suggestPreset(String content) {
    final detected = detectFromContent(content);
    if (detected.preset != TransportPresetId.plainTls ||
        detected.security != null ||
        detected.network != null) {
      return detected.preset;
    }
    return TransportPresetId.xhttpReality;
  }

  static String applyPresetToLink(
    String link, {
    required TransportPresetId preset,
    TlsFingerprint fingerprint = defaultFingerprint,
  }) {
    if (!LinkConfigBuilder.isConfigLink(link)) {
      return link;
    }
    final uri = Uri.parse(link);
    final params = Map<String, String>.from(uri.queryParameters);

    switch (preset) {
      case TransportPresetId.plainTls:
        params['type'] = 'tcp';
        params['security'] = 'tls';
        params.remove('mode');
      case TransportPresetId.wsTls:
        params['type'] = 'ws';
        params['security'] = 'tls';
        params.putIfAbsent('path', () => '/');
        params.remove('mode');
      case TransportPresetId.grpcTls:
        params['type'] = 'grpc';
        params['security'] = 'tls';
        params.putIfAbsent('serviceName', () => 'grpc');
        params.remove('mode');
      case TransportPresetId.httpUpgradeTls:
        params['type'] = 'httpupgrade';
        params['security'] = 'tls';
        params.putIfAbsent('path', () => '/');
        params.remove('mode');
      case TransportPresetId.reality:
        params['type'] = 'tcp';
        params['security'] = 'reality';
        params.remove('mode');
      case TransportPresetId.xhttpReality:
        params['type'] = 'xhttp';
        params['security'] = 'reality';
        params['mode'] = defaultXhttpMode;
        params.putIfAbsent('path', () => '/');
    }

    params['fp'] = fingerprint.wireValue;

    final fragment = uri.fragment.isNotEmpty ? '#${uri.fragment}' : '';
    final port = uri.hasPort ? ':${uri.port}' : '';
    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '${uri.scheme}://${uri.userInfo}@${uri.host}$port?$query$fragment';
  }
}
