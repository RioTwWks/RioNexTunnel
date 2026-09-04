import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/credentials.dart';
import '../models/dns_settings.dart';
import '../models/panel_socks_inbound.dart';
import '../models/pinning_config.dart';
import '../models/socks_auth_mode.dart';
import '../models/subscription_server.dart';
import '../models/vpn_engine.dart';
import 'amnezia_wg_config.dart';
import 'dns_config_builder.dart';
import 'subscription_http_client.dart';
import 'transport_presets.dart';

class ConfigParserException implements Exception {
  ConfigParserException(this.message);

  final String message;

  @override
  String toString() => 'ConfigParserException: $message';
}

class ConfigParser {
  static const int defaultSocksPort = 1080;
  static const int vulnerablePort = 7890;

  static bool isSingboxConfig(Map<String, dynamic> config) {
    return config.containsKey('outbounds') &&
        config['outbounds'] is List &&
        (config['outbounds'] as List).isNotEmpty &&
        (config['outbounds'] as List).first is Map &&
        ((config['outbounds'] as List).first as Map).containsKey('type');
  }

  static SubscriptionHttpClient _subscriptionHttpClient =
      SubscriptionHttpClient();

  @visibleForTesting
  static void setSubscriptionHttpClientForTesting(
    SubscriptionHttpClient client,
  ) {
    _subscriptionHttpClient = client;
  }

  static Future<String> fetchSubscriptionBody(
    String url, {
    required VpnEngine engine,
    PinningConfig? pinning,
  }) async {
    final response = await _subscriptionHttpClient.get(
      Uri.parse(url),
      headers: {
        'User-Agent': _subscriptionUserAgent(engine),
        'Accept-Encoding': 'identity',
      },
      pinning: pinning,
    );
    if (response.statusCode != 200) {
      throw ConfigParserException(
        'Failed to fetch subscription: HTTP ${response.statusCode}',
      );
    }
    return response.body.trim();
  }

  static Future<String> parseFromUrl(
    String url, {
    required VpnEngine engine,
    int serverIndex = 0,
    PinningConfig? pinning,
  }) async {
    final body = await fetchSubscriptionBody(
      url,
      engine: engine,
      pinning: pinning,
    );
    return normalizeSubscriptionContent(body, serverIndex: serverIndex);
  }

  static Future<List<SubscriptionServer>> listServersFromUrl(
    String url, {
    required VpnEngine engine,
    PinningConfig? pinning,
  }) async {
    final body = await fetchSubscriptionBody(
      url,
      engine: engine,
      pinning: pinning,
    );
    return listSubscriptionServers(body);
  }

  /// Subscription panels return different formats depending on User-Agent.
  /// Dart's default UA often yields an app-specific JSON bundle (e.g. Hiddify)
  /// that is unsuitable for desktop proxy mode.
  static String _subscriptionUserAgent(VpnEngine engine) {
    return engine == VpnEngine.singbox ? 'sing-box' : 'v2rayNG/1.8.29';
  }

  /// Converts subscription body to either JSON config or a single config link.
  ///
  /// [serverIndex] selects among non-decoy entries (0 = first real server).
  static String normalizeSubscriptionContent(
    String body, {
    int serverIndex = 0,
  }) {
    final servers = listSubscriptionServers(body);
    if (servers.isEmpty) {
      throw ConfigParserException(
        'Subscription does not contain JSON config or supported config links',
      );
    }
    if (serverIndex < 0 || serverIndex >= servers.length) {
      throw ConfigParserException(
        'Server index $serverIndex out of range '
        '(0..${servers.length - 1})',
      );
    }
    return servers[serverIndex].content;
  }

  /// Lists all non-decoy servers from a raw (or base64) subscription body.
  static List<SubscriptionServer> listSubscriptionServers(String body) {
    var content = body;
    try {
      final decoded = utf8.decode(base64.decode(_padBase64(body)));
      if (decoded.trim().isNotEmpty) {
        content = decoded.trim();
      }
    } catch (_) {
      // Not base64 — use raw body.
    }

    final trimmed = content.trim();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List || decoded.isEmpty) {
        throw ConfigParserException('Subscription JSON array is empty');
      }
      return _listV2rayNgServers(decoded);
    }

    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw ConfigParserException('Subscription JSON object is invalid');
      }
      final config = Map<String, dynamic>.from(decoded);
      if (_isDecoyXraySubscription(config)) {
        throw ConfigParserException(
          'Subscription does not contain a valid Xray server config',
        );
      }
      return [
        SubscriptionServer(
          index: 0,
          name: _nameFromXrayConfig(config, fallbackIndex: 0),
          content: trimmed,
        ),
      ];
    }

    final servers = <SubscriptionServer>[];
    for (final line in content.split('\n')) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.isEmpty || lineTrimmed.startsWith('#')) {
        continue;
      }
      if (_looksLikeConfigLink(lineTrimmed) && !_isDecoyLink(lineTrimmed)) {
        final index = servers.length;
        servers.add(
          SubscriptionServer(
            index: index,
            name: _nameFromConfigLink(lineTrimmed, fallbackIndex: index),
            content: lineTrimmed,
          ),
        );
      }
    }
    if (servers.isEmpty) {
      throw ConfigParserException(
        'Subscription does not contain JSON config or supported config links',
      );
    }
    return servers;
  }

  static List<SubscriptionServer> _listV2rayNgServers(List<dynamic> configs) {
    final servers = <SubscriptionServer>[];
    for (final raw in configs) {
      if (raw is! Map) {
        continue;
      }
      final config = Map<String, dynamic>.from(raw);
      if (_isDecoyXraySubscription(config)) {
        continue;
      }
      final index = servers.length;
      servers.add(
        SubscriptionServer(
          index: index,
          name: _nameFromXrayConfig(config, fallbackIndex: index),
          content: jsonEncode(config),
        ),
      );
    }
    if (servers.isEmpty) {
      throw ConfigParserException(
        'Subscription does not contain a valid Xray server config',
      );
    }
    return servers;
  }

  static String _nameFromXrayConfig(
    Map<String, dynamic> config, {
    required int fallbackIndex,
  }) {
    final remarks = config['remarks']?.toString().trim();
    if (remarks != null && remarks.isNotEmpty) {
      return remarks;
    }
    return 'Server ${fallbackIndex + 1}';
  }

  static String _nameFromConfigLink(String link, {required int fallbackIndex}) {
    final hash = link.indexOf('#');
    if (hash >= 0 && hash < link.length - 1) {
      final fragment = Uri.decodeComponent(link.substring(hash + 1)).trim();
      if (fragment.isNotEmpty) {
        return fragment;
      }
    }
    try {
      final uri = Uri.parse(link);
      if (uri.host.isNotEmpty) {
        return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
      }
    } catch (_) {
      // Fall through to numbered label.
    }
    return 'Server ${fallbackIndex + 1}';
  }

  static bool _isDecoyXraySubscription(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return true;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final protocol = raw['protocol']?.toString();
      if (protocol == 'vless' ||
          protocol == 'vmess' ||
          protocol == 'trojan' ||
          protocol == 'shadowsocks') {
        return false;
      }
    }
    return true;
  }

  static bool _isDecoyLink(String value) {
    final lower = value.toLowerCase();
    return lower.contains('fake_ip_for_sub_link') ||
        RegExp(r'20\.\d{2}--').hasMatch(lower);
  }

  static bool _looksLikeConfigLink(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://') ||
        lower.startsWith('hy2://') ||
        lower.startsWith('hysteria2://') ||
        lower.startsWith('hy://') ||
        lower.startsWith('hysteria://') ||
        lower.startsWith('tuic://') ||
        lower.startsWith('wg://') ||
        lower.startsWith('wireguard://') ||
        lower.startsWith('awg://') ||
        lower.startsWith('ssh://');
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }

  static PanelSocksInbound? extractPanelSocksAuth(
    Map<String, dynamic> config, {
    required VpnEngine engine,
  }) {
    final shortcut = _panelSocksFromShortcut(config);
    if (shortcut != null) return shortcut;
    final inbounds = config['inbounds'];
    if (inbounds is! List) return null;
    for (final raw in inbounds) {
      if (raw is! Map) continue;
      final inbound = Map<String, dynamic>.from(raw);
      if (!_isSocksInbound(inbound, engine)) continue;
      final listen = (inbound['listen'] ?? '127.0.0.1').toString();
      if (listen != '127.0.0.1' && listen != 'localhost') continue;
      if (engine == VpnEngine.xray) {
        final settings = inbound['settings'];
        if (settings is! Map || settings['auth']?.toString() != 'password') continue;
        final accounts = settings['accounts'];
        if (accounts is! List || accounts.isEmpty) continue;
        final account = accounts.first;
        if (account is! Map) continue;
        final user = account['user']?.toString() ?? '';
        final pass = account['pass']?.toString() ?? '';
        final port = inbound['port'];
        if (user.isEmpty || pass.isEmpty || port is! num) continue;
        return PanelSocksInbound(username: user, password: pass, port: port.toInt());
      }
      final users = inbound['users'];
      if (users is! List || users.isEmpty) continue;
      final userEntry = users.first;
      if (userEntry is! Map) continue;
      final user = userEntry['username']?.toString() ?? '';
      final pass = userEntry['password']?.toString() ?? '';
      final port = inbound['listen_port'] ?? inbound['port'];
      if (user.isEmpty || pass.isEmpty || port is! num) continue;
      return PanelSocksInbound(username: user, password: pass, port: port.toInt());
    }
    return null;
  }

  static PanelSocksInbound? _panelSocksFromShortcut(Map<String, dynamic> config) {
    for (final key in ['local_proxy', 'socks', 'localProxy']) {
      final raw = config[key];
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final user = map['username']?.toString() ?? map['user']?.toString() ?? '';
      final pass = map['password']?.toString() ?? map['pass']?.toString() ?? '';
      final portRaw = map['port'] ?? map['listen_port'];
      if (user.isEmpty || pass.isEmpty || portRaw is! num) continue;
      return PanelSocksInbound(username: user, password: pass, port: portRaw.toInt());
    }
    return null;
  }

  static String injectSecureSocksInbound(
    String jsonConfig,
    SessionCredentials credentials,
    VpnEngine engine, {
    int socksPort = defaultSocksPort,
    bool proxyOnly = false,
    SocksAuthMode authMode = SocksAuthMode.randomPerSession,
    PanelSocksInbound? panelSocks,
    DnsSettings? dnsSettings,
  }) {
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      throw ConfigParserException('Config root must be a JSON object');
    }
    final config = Map<String, dynamic>.from(decoded);
    if (engine == VpnEngine.xray) {
      _normalizeXraySubscriptionConfig(config);
      _normalizeXrayXhttpTransport(config);
      _stripDeprecatedXrayTlsFlags(config);
    }
    if (engine == VpnEngine.singbox) {
      _migrateSingboxLegacyDns(config);
      _normalizeSingboxXhttpTransport(config);
      _normalizeSingboxAwgOutbounds(config);
      DnsConfigBuilder.ensureSingboxRemoteDns(config, settings: dnsSettings);
      _ensureSingboxClashApi(config);
    } else if (dnsSettings != null && !proxyOnly) {
      DnsConfigBuilder.apply(config, dnsSettings, engine, proxyOnly: proxyOnly);
    }
    final skipInjection = authMode == SocksAuthMode.disableInjection;
    final effectivePort = authMode == SocksAuthMode.staticFromPanel &&
            panelSocks != null &&
            panelSocks.isValid
        ? panelSocks.port
        : socksPort;
    if (!skipInjection) {
      _sanitizeInboundsForProxy(config, engine, proxyOnly: proxyOnly);
    }
    _removeUnsafeSocksInbounds(config, engine);
    if (!skipInjection) {
      final inbound = engine == VpnEngine.singbox
          ? _buildSingboxSocksInbound(credentials, effectivePort)
          : _buildXraySocksInbound(credentials, effectivePort);
      final inbounds = <dynamic>[
        ...(config['inbounds'] as List<dynamic>? ?? const []),
        inbound,
      ];
      if (proxyOnly) {
        final httpPort = effectivePort + 1;
        inbounds.add(
          engine == VpnEngine.singbox
              ? _buildSingboxHttpInbound(credentials, httpPort)
              : _buildXrayHttpInbound(credentials, httpPort),
        );
      }
      config['inbounds'] = inbounds;
    }
    if (!proxyOnly && !skipInjection && engine == VpnEngine.xray) {
      _ensureXrayTunInbound(config);
    }
    validateSecure(jsonEncode(config), engine: engine);
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  /// Xray TUN inbound matching libXray / v2ray_box Android expectations.
  static void _ensureXrayTunInbound(Map<String, dynamic> config) {
    final inbounds = List<dynamic>.from(
      config['inbounds'] as List<dynamic>? ?? const [],
    );
    final hasTun = inbounds.any(
      (raw) => raw is Map && raw['protocol']?.toString() == 'tun',
    );
    if (!hasTun) {
      inbounds.insert(0, {
        'tag': 'tun-in',
        'protocol': 'tun',
        'settings': {'name': 'xray0', 'MTU': 1500, 'userLevel': 8},
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        },
      });
      config['inbounds'] = inbounds;
    }

    final policy = config['policy'];
    if (policy is! Map) {
      config['policy'] = {
        'levels': {
          '8': {
            'handshake': 4,
            'connIdle': 300,
            'uplinkOnly': 1,
            'downlinkOnly': 1,
          },
        },
      };
      return;
    }
    final levels = policy['levels'];
    if (levels is Map && levels.containsKey('8')) {
      return;
    }
    final updated = Map<String, dynamic>.from(policy);
    final updatedLevels = levels is Map
        ? Map<String, dynamic>.from(levels)
        : <String, dynamic>{};
    updatedLevels.putIfAbsent(
      '8',
      () => {
        'handshake': 4,
        'connIdle': 300,
        'uplinkOnly': 1,
        'downlinkOnly': 1,
      },
    );
    updated['levels'] = updatedLevels;
    config['policy'] = updated;
  }

  static Map<String, dynamic> _buildXraySocksInbound(
    SessionCredentials credentials,
    int socksPort,
  ) {
    return {
      'tag': 'secure-socks-in',
      'listen': '127.0.0.1',
      'port': socksPort,
      'protocol': 'socks',
      'sniffing': {
        'enabled': true,
        'destOverride': ['http', 'tls'],
      },
      'settings': {
        'auth': 'password',
        'accounts': [
          {'user': credentials.username, 'pass': credentials.password},
        ],
        'udp': true,
      },
    };
  }

  static Map<String, dynamic> _buildXrayHttpInbound(
    SessionCredentials credentials,
    int httpPort,
  ) {
    return {
      'tag': 'secure-http-in',
      'listen': '127.0.0.1',
      'port': httpPort,
      'protocol': 'http',
      'settings': {
        'accounts': [
          {'user': credentials.username, 'pass': credentials.password},
        ],
      },
    };
  }

  static Map<String, dynamic> _buildSingboxHttpInbound(
    SessionCredentials credentials,
    int httpPort,
  ) {
    return {
      'type': 'http',
      'tag': 'secure-http-in',
      'listen': '127.0.0.1',
      'listen_port': httpPort,
      'users': [
        {'username': credentials.username, 'password': credentials.password},
      ],
    };
  }

  static Map<String, dynamic> _buildSingboxSocksInbound(
    SessionCredentials credentials,
    int socksPort,
  ) {
    return {
      'type': 'socks',
      'tag': 'secure-socks-in',
      'listen': '127.0.0.1',
      'listen_port': socksPort,
      'users': [
        {'username': credentials.username, 'password': credentials.password},
      ],
    };
  }

  /// Coerces XHTTP `mode: auto` (or missing mode) to [TransportPresets.defaultXhttpMode]
  /// on proxy outbounds. Preserves path, host, and other XHTTP fields from subscription JSON.
  static void _normalizeXrayXhttpTransport(Map<String, dynamic> config) {
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
      if (!_isXrayProxyOutbound(outbound)) {
        continue;
      }
      _normalizeXrayOutboundXhttp(outbound);
      outbounds[i] = outbound;
    }
    config['outbounds'] = outbounds;
  }

  static void _normalizeSingboxXhttpTransport(Map<String, dynamic> config) {
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
      if (!_isSingboxProxyOutbound(outbound)) {
        continue;
      }
      _normalizeSingboxOutboundXhttp(outbound);
      outbounds[i] = outbound;
    }
    config['outbounds'] = outbounds;
  }

  static bool _isXrayProxyOutbound(Map<String, dynamic> outbound) {
    final protocol = outbound['protocol']?.toString();
    return protocol == 'vless' ||
        protocol == 'vmess' ||
        protocol == 'trojan' ||
        protocol == 'shadowsocks';
  }

  static bool _isSingboxProxyOutbound(Map<String, dynamic> outbound) {
    final type = outbound['type']?.toString();
    return type == 'vless' ||
        type == 'vmess' ||
        type == 'trojan' ||
        type == 'shadowsocks';
  }

  static void _normalizeXrayOutboundXhttp(Map<String, dynamic> outbound) {
    final stream = outbound['streamSettings'];
    if (stream is! Map) {
      return;
    }
    final streamMap = Map<String, dynamic>.from(stream);
    final network = streamMap['network']?.toString().toLowerCase();
    final hasXhttpSettings = streamMap['xhttpSettings'] is Map;
    if (network != 'xhttp' && !hasXhttpSettings) {
      return;
    }

    streamMap['network'] = 'xhttp';
    final xhttpRaw = streamMap['xhttpSettings'];
    final xhttp = xhttpRaw is Map
        ? Map<String, dynamic>.from(xhttpRaw)
        : <String, dynamic>{};
    xhttp.putIfAbsent('path', () => '/');
    xhttp['mode'] = _resolveXhttpMode(xhttp['mode']);
    streamMap['xhttpSettings'] = xhttp;
    outbound['streamSettings'] = streamMap;
  }

  static void _normalizeSingboxOutboundXhttp(Map<String, dynamic> outbound) {
    final transport = outbound['transport'];
    if (transport is! Map) {
      return;
    }
    final transportMap = Map<String, dynamic>.from(transport);
    if (transportMap['type']?.toString().toLowerCase() != 'xhttp') {
      return;
    }

    transportMap.putIfAbsent('path', () => '/');
    transportMap['mode'] = _resolveXhttpMode(transportMap['mode']);
    outbound['transport'] = transportMap;
  }

  static String _resolveXhttpMode(dynamic mode) {
    final value = mode?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'auto') {
      return TransportPresets.defaultXhttpMode;
    }
    return value;
  }

  /// True when imported JSON still contains XHTTP `mode: auto` before normalization.
  static bool configHasXhttpAutoMode(String jsonConfig) {
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }
    final outbounds = decoded['outbounds'];
    if (outbounds is! List) {
      return false;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final outbound = Map<String, dynamic>.from(raw);
      if (outbound.containsKey('type')) {
        final transport = outbound['transport'];
        if (transport is Map &&
            transport['type']?.toString().toLowerCase() == 'xhttp' &&
            transport['mode']?.toString().toLowerCase() == 'auto') {
          return true;
        }
        continue;
      }
      final stream = outbound['streamSettings'];
      if (stream is Map &&
          stream['network']?.toString().toLowerCase() == 'xhttp') {
        final xhttp = stream['xhttpSettings'];
        if (xhttp is Map && xhttp['mode']?.toString().toLowerCase() == 'auto') {
          return true;
        }
      }
    }
    return false;
  }

  static void _normalizeXraySubscriptionConfig(Map<String, dynamic> config) {
    final proxyTag = _primaryXrayOutboundTag(config);
    if (proxyTag == null) {
      return;
    }

    final routing = config['routing'];
    if (routing is! Map) {
      return;
    }
    final rules = routing['rules'];
    if (rules is! List) {
      return;
    }

    routing['rules'] = rules
        .map((rule) {
          if (rule is! Map) {
            return rule;
          }
          final normalized = Map<String, dynamic>.from(rule);
          final inboundTag = normalized['inboundTag'];
          if (inboundTag == 'api' ||
              (inboundTag is List && inboundTag.contains('api'))) {
            return null;
          }
          if (normalized['outboundTag'] == 'proxy') {
            normalized['outboundTag'] = proxyTag;
          }
          return normalized;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Removes deprecated Xray TLS keys rejected by current libXray builds.
  ///
  /// `allowInsecure` was removed in favor of pinnedPeerCertSha256 /
  /// verifyPeerCertByName. Stripping forces normal certificate verification.
  static void _stripDeprecatedXrayTlsFlags(Map<String, dynamic> config) {
    _stripDeprecatedTlsKeysRecursive(config);
  }

  static void _stripDeprecatedTlsKeysRecursive(dynamic node) {
    if (node is Map) {
      node.remove('allowInsecure');
      // Older panels sometimes emit the alias under stream settings.
      node.remove('allow_insecure');
      for (final value in node.values) {
        _stripDeprecatedTlsKeysRecursive(value);
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        _stripDeprecatedTlsKeysRecursive(item);
      }
    }
  }

  static String? _primaryXrayOutboundTag(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return null;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final protocol = raw['protocol']?.toString();
      if (protocol == 'vless' ||
          protocol == 'vmess' ||
          protocol == 'trojan' ||
          protocol == 'shadowsocks') {
        return raw['tag']?.toString();
      }
    }
    return null;
  }

  static void _sanitizeInboundsForProxy(
    Map<String, dynamic> config,
    VpnEngine engine, {
    bool proxyOnly = false,
  }) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }

    final removedTags = <String>{};
    final kept = <dynamic>[];

    for (final raw in inbounds) {
      if (raw is! Map) {
        if (!proxyOnly) {
          kept.add(raw);
        }
        continue;
      }
      final inbound = Map<String, dynamic>.from(raw);
      final tag = inbound['tag']?.toString();
      if (proxyOnly) {
        if (tag != null && tag.isNotEmpty) {
          removedTags.add(tag);
        }
        continue;
      }
      final valid = engine == VpnEngine.singbox
          ? _isValidSingboxInboundForProxy(inbound)
          : _isValidXrayInboundForProxy(inbound);
      if (!valid) {
        if (tag != null && tag.isNotEmpty) {
          removedTags.add(tag);
        }
        continue;
      }
      kept.add(inbound);
    }

    config['inbounds'] = kept;
    if (removedTags.isNotEmpty) {
      _sanitizeRoutingForRemovedInbounds(config, engine, removedTags);
    }
  }

  static void _migrateSingboxLegacyDns(Map<String, dynamic> config) {
    final dns = config['dns'];
    if (dns is! Map) {
      return;
    }
    final servers = dns['servers'];
    if (servers is! List) {
      return;
    }

    final migrated = <Map<String, dynamic>>[];
    for (final raw in servers) {
      if (raw is String) {
        migrated.add({
          'type': raw == 'local' ? 'local' : 'udp',
          if (raw != 'local') 'server': raw,
          'tag': 'dns-${migrated.length}',
        });
        continue;
      }
      if (raw is! Map) {
        continue;
      }
      final server = Map<String, dynamic>.from(raw);
      if (server.containsKey('type')) {
        migrated.add(server);
        continue;
      }
      final address = server['address']?.toString();
      if (address == null || address.isEmpty) {
        continue;
      }
      final tag = server['tag']?.toString() ?? 'dns-${migrated.length}';
      final detour = server['detour'];
      final strategy = server['strategy'];
      final resolver = server['address_resolver'];

      Map<String, dynamic> migratedServer;
      if (address == 'local' || address == 'dhcp://') {
        migratedServer = {'type': 'local', 'tag': tag};
      } else if (address.startsWith('tcp://')) {
        migratedServer = {
          'type': 'tcp',
          'server': address.substring(6),
          'tag': tag,
        };
      } else if (address.startsWith('udp://')) {
        migratedServer = {
          'type': 'udp',
          'server': address.substring(6),
          'tag': tag,
        };
      } else if (address.startsWith('https://') ||
          address.startsWith('h3://') ||
          address.startsWith('quic://')) {
        migratedServer = {'type': 'https', 'server': address, 'tag': tag};
      } else if (address.startsWith('rcode://')) {
        migratedServer = {'type': 'empty', 'tag': tag};
      } else {
        migratedServer = {'type': 'udp', 'server': address, 'tag': tag};
      }
      if (detour != null) {
        migratedServer['detour'] = detour;
      }
      if (strategy != null) {
        migratedServer['strategy'] = strategy;
      }
      if (resolver != null) {
        migratedServer['address_resolver'] = resolver;
      }
      migrated.add(migratedServer);
    }
    dns['servers'] = migrated;
  }

  /// Local Clash API for traffic stats (CommandClient polls 127.0.0.1:9090).
  static void _ensureSingboxClashApi(Map<String, dynamic> config) {
    final experimental = config['experimental'];
    final experimentalMap = experimental is Map
        ? Map<String, dynamic>.from(experimental)
        : <String, dynamic>{};

    final clashApi = experimentalMap['clash_api'];
    final clashMap = clashApi is Map
        ? Map<String, dynamic>.from(clashApi)
        : <String, dynamic>{};

    final controller = clashMap['external_controller']?.toString() ?? '';
    if (controller.isEmpty ||
        controller.startsWith('0.0.0.0') ||
        controller.startsWith('[::]')) {
      clashMap['external_controller'] = '127.0.0.1:9090';
    }
    experimentalMap['clash_api'] = clashMap;
    config['experimental'] = experimentalMap;
  }

  static bool _isValidXrayInboundForProxy(Map<String, dynamic> inbound) {
    final protocol = inbound['protocol']?.toString();
    if (protocol == 'tun') {
      return false;
    }

    final port = inbound['port'];
    if (port == null) {
      return false;
    }
    return true;
  }

  static bool _isValidSingboxInboundForProxy(Map<String, dynamic> inbound) {
    final type = inbound['type']?.toString();
    if (type == 'tun' || type == 'mixed') {
      return false;
    }

    final port = inbound['listen_port'] ?? inbound['port'];
    if (port == null) {
      return false;
    }
    return true;
  }

  static void _sanitizeRoutingForRemovedInbounds(
    Map<String, dynamic> config,
    VpnEngine engine,
    Set<String> removedTags,
  ) {
    if (engine == VpnEngine.xray) {
      final routing = config['routing'];
      if (routing is! Map) {
        return;
      }
      final rules = routing['rules'];
      if (rules is! List) {
        return;
      }
      routing['rules'] = rules.where((rule) {
        if (rule is! Map) {
          return true;
        }
        final inboundTag = rule['inboundTag'];
        if (inboundTag is List) {
          return !inboundTag.any((tag) => removedTags.contains(tag.toString()));
        }
        if (inboundTag is String) {
          return !removedTags.contains(inboundTag);
        }
        return true;
      }).toList();
      return;
    }

    final route = config['route'];
    if (route is! Map) {
      return;
    }
    final rules = route['rules'];
    if (rules is! List) {
      return;
    }
    route['rules'] = rules.where((rule) {
      if (rule is! Map) {
        return true;
      }
      final inbound = rule['inbound'];
      if (inbound is List) {
        return !inbound.any((tag) => removedTags.contains(tag.toString()));
      }
      if (inbound is String) {
        return !removedTags.contains(inbound);
      }
      return true;
    }).toList();
  }

  static void _removeUnsafeSocksInbounds(
    Map<String, dynamic> config,
    VpnEngine engine,
  ) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }

    config['inbounds'] = inbounds.where((raw) {
      if (raw is! Map) {
        return true;
      }
      final inbound = Map<String, dynamic>.from(raw);
      if (!_isSocksInbound(inbound, engine)) {
        return true;
      }
      return !_isUnsafeSocksInbound(inbound, engine);
    }).toList();
  }

  static bool _isSocksInbound(Map<String, dynamic> inbound, VpnEngine engine) {
    if (engine == VpnEngine.singbox) {
      return inbound['type'] == 'socks';
    }
    return inbound['protocol'] == 'socks';
  }

  static bool _isUnsafeSocksInbound(
    Map<String, dynamic> inbound,
    VpnEngine engine,
  ) {
    final listen = (inbound['listen'] ?? '127.0.0.1').toString();
    final port = engine == VpnEngine.singbox
        ? inbound['listen_port'] ?? inbound['port']
        : inbound['port'];

    if (listen == '0.0.0.0' || listen == '::' || listen == '::0') {
      return true;
    }
    if (port == vulnerablePort) {
      return true;
    }

    if (engine == VpnEngine.xray) {
      final settings = inbound['settings'];
      if (settings is Map) {
        final auth = settings['auth']?.toString();
        if (auth == null || auth == 'noauth') {
          return true;
        }
      } else {
        return true;
      }
    }

    if (engine == VpnEngine.singbox) {
      final users = inbound['users'];
      if (users is! List || users.isEmpty) {
        return true;
      }
    }

    return false;
  }

  /// True when config JSON references Xray-style `geosite:` / `geoip:` rules.
  static bool configRequiresXrayGeoRules(String jsonConfig) {
    final lower = jsonConfig.toLowerCase();
    return lower.contains('geosite:') || lower.contains('geoip:');
  }

  static void validateSecure(String jsonConfig, {VpnEngine? engine}) {
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      throw ConfigParserException('Config root must be a JSON object');
    }

    final detectedEngine =
        engine ??
        (isSingboxConfig(decoded) ? VpnEngine.singbox : VpnEngine.xray);
    final inbounds = decoded['inbounds'];
    if (inbounds is! List || inbounds.isEmpty) {
      throw ConfigParserException('Config must contain at least one inbound');
    }

    final socksInbounds = inbounds
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((inbound) => _isSocksInbound(inbound, detectedEngine))
        .toList();

    if (socksInbounds.isEmpty) {
      throw ConfigParserException('Config must contain a SOCKS inbound');
    }

    for (final inbound in socksInbounds) {
      final listen = (inbound['listen'] ?? '127.0.0.1').toString();
      if (listen != '127.0.0.1') {
        throw ConfigParserException('SOCKS inbound must bind to 127.0.0.1');
      }

      final port = detectedEngine == VpnEngine.singbox
          ? inbound['listen_port'] ?? inbound['port']
          : inbound['port'];
      if (port == vulnerablePort) {
        throw ConfigParserException(
          'Vulnerable port $vulnerablePort is not allowed',
        );
      }

      if (detectedEngine == VpnEngine.xray) {
        final settings = inbound['settings'];
        if (settings is! Map || settings['auth'] != 'password') {
          throw ConfigParserException(
            'Xray SOCKS inbound must use password auth',
          );
        }
        final accounts = settings['accounts'];
        if (accounts is! List || accounts.isEmpty) {
          throw ConfigParserException('Xray SOCKS inbound requires accounts');
        }
      } else {
        final users = inbound['users'];
        if (users is! List || users.isEmpty) {
          throw ConfigParserException('sing-box SOCKS inbound requires users');
        }
      }
    }
  }
}
