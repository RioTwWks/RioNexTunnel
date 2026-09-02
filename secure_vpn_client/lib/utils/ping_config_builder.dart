import 'dart:convert';
import 'dart:io';

import '../models/vpn_engine.dart';
import 'config_parser.dart';
import 'link_config_builder.dart';

/// Temporary core config used for tunnel-quality latency probes.
class PingMeasureConfig {
  const PingMeasureConfig({
    required this.configJson,
    required this.socksPort,
    required this.engine,
  });

  final String configJson;
  final int socksPort;
  final VpnEngine engine;
}

/// Builds minimal Xray/sing-box configs that route local inbound traffic through
/// one subscription outbound (full tunnel path, not raw TCP to host:port).
class PingConfigBuilder {
  static VpnEngine resolveEngine(String content, VpnEngine preference) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return preference;
    }
    if (LinkConfigBuilder.isConfigLink(trimmed)) {
      if (LinkConfigBuilder.requiresSingbox(trimmed)) {
        return VpnEngine.singbox;
      }
      return preference;
    }
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return _engineForJson(decoded, preference);
        }
      } catch (_) {
        return preference;
      }
    }
    return preference;
  }

  static PingMeasureConfig build(String content, VpnEngine preference) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ConfigParserException('Empty server content for latency probe');
    }

    final engine = resolveEngine(trimmed, preference);
    final socksPort = _allocateSocksPort();
    final outbound = _proxyOutboundFromContent(trimmed, engine);
    final configJson = engine == VpnEngine.singbox
        ? _buildSingboxMeasureConfig(outbound, socksPort)
        : _buildXrayMeasureConfig(outbound, socksPort);

    return PingMeasureConfig(
      configJson: configJson,
      socksPort: socksPort,
      engine: engine,
    );
  }

  static VpnEngine _engineForJson(
    Map<String, dynamic> config,
    VpnEngine preference,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is List && outbounds.isNotEmpty) {
      final first = outbounds.first;
      if (first is Map) {
        if (first.containsKey('type') && !first.containsKey('protocol')) {
          return VpnEngine.singbox;
        }
      }
    }
    return preference;
  }

  static Map<String, dynamic> _proxyOutboundFromContent(
    String content,
    VpnEngine engine,
  ) {
    if (LinkConfigBuilder.isConfigLink(content)) {
      final fullConfigJson = LinkConfigBuilder.buildFromLink(content, engine);
      final config = jsonDecode(fullConfigJson) as Map<String, dynamic>;
      return _extractProxyOutbound(config, engine);
    }
    if (content.startsWith('{')) {
      final config = jsonDecode(content) as Map<String, dynamic>;
      return _extractProxyOutbound(config, engine);
    }
    throw ConfigParserException('Unsupported server content for latency probe');
  }

  static Map<String, dynamic> _extractProxyOutbound(
    Map<String, dynamic> config,
    VpnEngine engine,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      throw ConfigParserException('Config has no outbounds for latency probe');
    }

    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final outbound = Map<String, dynamic>.from(raw);
      if (engine == VpnEngine.xray) {
        final protocol = outbound['protocol']?.toString();
        if (protocol == null ||
            protocol == 'freedom' ||
            protocol == 'blackhole' ||
            protocol == 'dns') {
          continue;
        }
        outbound.remove('mux');
        outbound['tag'] = 'proxy';
        return outbound;
      }

      final type = outbound['type']?.toString();
      if (type == null ||
          type == 'direct' ||
          type == 'block' ||
          type == 'dns' ||
          type == 'selector' ||
          type == 'urltest') {
        continue;
      }
      outbound['tag'] = 'proxy';
      return outbound;
    }

    throw ConfigParserException('No proxy outbound found for latency probe');
  }

  static String _buildXrayMeasureConfig(
    Map<String, dynamic> outbound,
    int socksPort,
  ) {
    final config = {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'protocol': 'socks',
          'listen': '127.0.0.1',
          'port': socksPort,
          'settings': {'udp': true, 'auth': 'noauth'},
        },
      ],
      'outbounds': [
        outbound,
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {'domainStrategy': 'UseIP'},
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
          'settings': {'response': {'type': 'http'}},
        },
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'type': 'field',
            'inboundTag': ['socks'],
            'outboundTag': 'proxy',
          },
        ],
      },
    };
    return jsonEncode(config);
  }

  static String _buildSingboxMeasureConfig(
    Map<String, dynamic> outbound,
    int socksPort,
  ) {
    final config = {
      'log': {'level': 'warn'},
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': socksPort,
        },
      ],
      'outbounds': [
        outbound,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'rules': [
          {
            'inbound': ['mixed-in'],
            'outbound': 'proxy',
          },
        ],
        'final': 'direct',
      },
    };
    return jsonEncode(config);
  }

  static int _allocateSocksPort() {
    try {
      final socket = RawSocket.bindSync(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      socket.close();
      return port;
    } catch (_) {
      return 10808;
    }
  }
}
