import 'dart:convert';

import '../models/transport_stack.dart';
import '../models/subscription_server.dart';
import 'link_config_builder.dart';
import 'transport_presets.dart';

class TransportStackClassifier {
  TransportStackClassifier._();

  static TransportStackKind classify(SubscriptionServer server) {
    final fromTags = _classifyFromTags(server.name);
    if (fromTags != null) {
      return fromTags;
    }
    return classifyContent(server.content);
  }

  static TransportStackKind classifyContent(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) {
      return _classifyJson(trimmed);
    }
    if (LinkConfigBuilder.isConfigLink(trimmed)) {
      return _classifyLink(trimmed);
    }
    return TransportStackKind.other;
  }

  static String tagFor(TransportStackKind kind) => kind.shortLabel;

  static String stackSummary(TransportStackKind kind, String content) {
    final detected = TransportPresets.detectFromContent(content);
    final parts = <String>[
      kind.shortLabel,
      if (detected.security != null && detected.security!.isNotEmpty)
        detected.security!,
      if (detected.fingerprint != null && detected.fingerprint!.isNotEmpty)
        detected.fingerprint!,
      if (detected.hasMux) 'mux',
    ];
    if (parts.length <= 1) {
      return detected.stackSummary;
    }
    return parts.join(' · ');
  }

  static TransportStackKind? _classifyFromTags(String name) {
    final lower = name.toLowerCase();
    if (_containsAny(lower, ['amnezia', 'amneziawg', 'awg'])) {
      return TransportStackKind.amneziaWg;
    }
    if (_containsAny(lower, ['xhttp', 'splithttp']) &&
        _containsAny(lower, ['reality', 'real'])) {
      return TransportStackKind.xhttpReality;
    }
    if (_containsAny(lower, ['vision', 'xtls-rprx-vision'])) {
      return TransportStackKind.tcpRealityVision;
    }
    if (_containsAny(lower, ['mux', 'mobile'])) {
      return TransportStackKind.tlsMux;
    }
    if (_containsAny(lower, ['xhttp'])) {
      return TransportStackKind.xhttpReality;
    }
    return null;
  }

  static TransportStackKind _classifyLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;
      final type = (params['type'] ?? 'tcp').toLowerCase();
      final security = (params['security'] ?? '').toLowerCase();
      final flow = (params['flow'] ?? '').toLowerCase();
      final scheme = uri.scheme.toLowerCase();

      if (scheme == 'wg' || scheme == 'wireguard') {
        return TransportStackKind.amneziaWg;
      }
      if (type == 'xhttp' && security == 'reality') {
        return TransportStackKind.xhttpReality;
      }
      if (security == 'reality' && type == 'tcp' && flow.contains('vision')) {
        return TransportStackKind.tcpRealityVision;
      }
      if (security == 'tls' &&
          (params['mux'] == '1' || _nameImpliesMux(uri.fragment))) {
        return TransportStackKind.tlsMux;
      }
      if (security == 'reality' && type == 'tcp') {
        return TransportStackKind.tcpRealityVision;
      }
      return TransportStackKind.other;
    } catch (_) {
      return TransportStackKind.other;
    }
  }

  static TransportStackKind _classifyJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        return TransportStackKind.other;
      }
      final outbound = _firstProxyOutbound(Map<String, dynamic>.from(decoded));
      if (outbound == null) {
        return TransportStackKind.other;
      }
      if (outbound.containsKey('type')) {
        return _classifySingboxOutbound(outbound);
      }
      return _classifyXrayOutbound(outbound);
    } catch (_) {
      return TransportStackKind.other;
    }
  }

  static TransportStackKind _classifyXrayOutbound(Map<String, dynamic> outbound) {
    final stream = outbound['streamSettings'];
    if (stream is! Map) {
      return TransportStackKind.other;
    }
    final network = stream['network']?.toString().toLowerCase() ?? 'tcp';
    final security = stream['security']?.toString().toLowerCase() ?? '';
    final flow = outbound['flow']?.toString().toLowerCase() ?? '';
    final mux = outbound['mux'];
    final muxEnabled = mux is Map && mux['enabled'] == true;

    if (network == 'xhttp' && security == 'reality') {
      return TransportStackKind.xhttpReality;
    }
    if (security == 'reality' && network == 'tcp' && flow.contains('vision')) {
      return TransportStackKind.tcpRealityVision;
    }
    if (security == 'tls' && muxEnabled) {
      return TransportStackKind.tlsMux;
    }
    if (security == 'reality' && network == 'tcp') {
      return TransportStackKind.tcpRealityVision;
    }
    return TransportStackKind.other;
  }

  static TransportStackKind _classifySingboxOutbound(
    Map<String, dynamic> outbound,
  ) {
    final type = outbound['type']?.toString().toLowerCase() ?? '';
    if (type == 'wireguard') {
      return TransportStackKind.amneziaWg;
    }
    final tls = outbound['tls'];
    var security = '';
    if (tls is Map) {
      if (tls['reality'] is Map && (tls['reality'] as Map)['enabled'] == true) {
        security = 'reality';
      } else if (tls['enabled'] == true) {
        security = 'tls';
      }
    }
    var network = 'tcp';
    final transport = outbound['transport'];
    if (transport is Map) {
      network = transport['type']?.toString().toLowerCase() ?? 'tcp';
    }
    if (network == 'xhttp' && security == 'reality') {
      return TransportStackKind.xhttpReality;
    }
    if (security == 'reality' && network == 'tcp') {
      return TransportStackKind.tcpRealityVision;
    }
    if (security == 'tls') {
      return TransportStackKind.tlsMux;
    }
    return TransportStackKind.other;
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
          type == 'trojan' ||
          type == 'wireguard') {
        return outbound;
      }
    }
    return null;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static bool _nameImpliesMux(String fragment) {
    final lower = fragment.toLowerCase();
    return lower.contains('mux') || lower.contains('mobile');
  }

  static String serverKey(SubscriptionServer server) {
    final fromContent = _keyFromContent(server.content);
    if (fromContent != null) {
      return fromContent;
    }
    return _normalizeName(server.name);
  }

  static String? _keyFromContent(String content) {
    final trimmed = content.trim();
    if (LinkConfigBuilder.isConfigLink(trimmed)) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.host.isNotEmpty) {
          final port = uri.hasPort ? uri.port : _defaultPort(uri.scheme);
          return '${uri.host.toLowerCase()}:$port';
        }
      } catch (_) {}
    }
    return null;
  }

  static int _defaultPort(String scheme) {
    return switch (scheme.toLowerCase()) {
      'trojan' || 'vless' || 'vmess' => 443,
      'wg' || 'wireguard' => 51820,
      _ => 443,
    };
  }

  static String _normalizeName(String name) {
    var normalized = name.trim().toLowerCase();
    for (final suffix in [
      '-xhttp', '_xhttp', ' xhttp',
      '-mux', '_mux', ' mux',
      '-vision', '_vision', ' vision',
      '-amnezia', '_amnezia', ' amnezia', '-awg', '_awg',
    ]) {
      final index = normalized.indexOf(suffix);
      if (index > 0) {
        normalized = normalized.substring(0, index).trim();
      }
    }
    return normalized.isEmpty ? name.trim().toLowerCase() : normalized;
  }
}
