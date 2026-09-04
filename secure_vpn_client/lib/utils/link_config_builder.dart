import 'dart:convert';

import '../models/transport_preset.dart';
import '../models/vpn_engine.dart';
import 'config_enhancer.dart';
import 'config_parser.dart';
import 'dns_config_builder.dart';
import 'transport_presets.dart';

class LinkConfigBuilder {
  /// Share-link schemes accepted by the app (subscription lines + profiles).
  static const supportedSchemes = [
    'vless',
    'vmess',
    'trojan',
    'ss',
    'hy',
    'hysteria',
    'hy2',
    'hysteria2',
    'tuic',
    'wg',
    'wireguard',
    'ssh',
  ];

  /// Protocols that only work with sing-box (not stock Xray-core).
  static const singboxOnlySchemes = [
    'hy',
    'hysteria',
    'hy2',
    'hysteria2',
    'tuic',
    'wg',
    'wireguard',
    'ssh',
  ];

  static bool isConfigLink(String value) {
    final scheme = _schemeOf(value);
    return scheme != null && supportedSchemes.contains(scheme);
  }

  /// True when the link must be built/run with sing-box.
  static bool requiresSingbox(String value) {
    final scheme = _schemeOf(value);
    return scheme != null && singboxOnlySchemes.contains(scheme);
  }

  static String buildFromLink(
    String link,
    VpnEngine engine, {
    LinkBuildOptions options = const LinkBuildOptions(),
  }) {
    final normalized = link.trim();
    if (!isConfigLink(normalized)) {
      throw ConfigParserException('Unsupported config link format');
    }

    if (requiresSingbox(normalized) && engine != VpnEngine.singbox) {
      throw ConfigParserException(
        'This protocol requires the sing-box engine '
        '(Hysteria, Hysteria2, TUIC, WireGuard, SSH). '
        'Switch engine preference to Auto or sing-box.',
      );
    }

    return engine == VpnEngine.singbox
        ? _buildSingbox(normalized, options)
        : _buildXray(normalized, options);
  }

  static String? _schemeOf(String value) {
    final trimmed = value.trim();
    final sep = trimmed.indexOf('://');
    if (sep <= 0) {
      return null;
    }
    return trimmed.substring(0, sep).toLowerCase();
  }

  static String _buildXray(String link, LinkBuildOptions options) {
    final outbound = _parseXrayOutbound(link, options);
    final config = {
      'log': {'loglevel': 'warning'},
      'inbounds': <dynamic>[],
      'outbounds': [
        outbound,
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'routing': {'domainStrategy': 'AsIs', 'rules': <dynamic>[]},
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static String _buildSingbox(String link, LinkBuildOptions options) {
    final outbound = _parseSingboxOutbound(link, options);
    final config = {
      'log': {'level': 'warn'},
      // Never use type:local on Android VPN — system resolver hits [::1]:53
      // and fails while TUN is up. Bootstrap with IP DNS via direct.
      'dns': DnsConfigBuilder.defaultSingboxDnsBlock(),
      'inbounds': <dynamic>[],
      'outbounds': [
        outbound,
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': {
        'rules': <dynamic>[],
        'final': 'proxy',
        'default_domain_resolver': {
          'server': 'dns-direct',
          'strategy': 'prefer_ipv4',
        },
      },
      'experimental': {
        'clash_api': {'external_controller': '127.0.0.1:9090'},
      },
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static Map<String, dynamic> _parseXrayOutbound(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseXrayVless(link, options);
    }
    if (lower.startsWith('trojan://')) {
      return _parseXrayTrojan(link, options);
    }
    if (lower.startsWith('vmess://')) {
      return _parseXrayVmess(link, options);
    }
    if (lower.startsWith('ss://')) {
      return _parseXrayShadowsocks(link);
    }
    throw ConfigParserException('Unsupported Xray link');
  }

  static Map<String, dynamic> _parseSingboxOutbound(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseSingboxVless(link, options);
    }
    if (lower.startsWith('trojan://')) {
      return _parseSingboxTrojan(link, options);
    }
    if (lower.startsWith('vmess://')) {
      return _parseSingboxVmess(link, options);
    }
    if (lower.startsWith('ss://')) {
      return _parseSingboxShadowsocks(link);
    }
    if (lower.startsWith('hy2://') || lower.startsWith('hysteria2://')) {
      return _parseSingboxHysteria2(link);
    }
    if (lower.startsWith('hy://') || lower.startsWith('hysteria://')) {
      return _parseSingboxHysteria(link);
    }
    if (lower.startsWith('tuic://')) {
      return _parseSingboxTuic(link);
    }
    if (lower.startsWith('wg://') || lower.startsWith('wireguard://')) {
      return _parseSingboxWireGuard(link);
    }
    if (lower.startsWith('ssh://')) {
      return _parseSingboxSsh(link);
    }
    throw ConfigParserException('Unsupported sing-box link');
  }

  static Map<String, dynamic> _parseXrayVless(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final server = uri.host;
    if (uuid.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid vless link');
    }
    final port = uri.port > 0 ? uri.port : 443;
    final params = uri.queryParameters;

    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': uuid,
                'encryption': params['encryption'] ?? 'none',
                if (params['flow']?.isNotEmpty == true) 'flow': params['flow'],
              },
            ],
          },
        ],
      },
      'streamSettings': _xrayStreamSettings(params, server, options),
    };
    _maybeApplyXrayMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseXrayTrojan(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    final port = uri.port > 0 ? uri.port : 443;
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {'address': server, 'port': port, 'password': password},
        ],
      },
      'streamSettings': _xrayStreamSettings(uri.queryParameters, server, options),
    };
    _maybeApplyXrayMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseXrayVmess(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final encoded = link.substring('vmess://'.length);
    final decoded = utf8.decode(base64.decode(_padBase64(encoded)));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final server = json['add']?.toString();
    final uuid = json['id']?.toString();
    if (server == null || uuid == null) {
      throw ConfigParserException('Invalid vmess link');
    }
    final port = int.tryParse(json['port']?.toString() ?? '') ?? 443;
    final params = <String, String>{
      if (json['net'] != null) 'type': json['net'].toString(),
      if (json['tls']?.toString() == 'tls') 'security': 'tls',
      if (json['sni'] != null) 'sni': json['sni'].toString(),
      if (json['host'] != null) 'host': json['host'].toString(),
      if (json['path'] != null) 'path': json['path'].toString(),
    };
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': uuid,
                'alterId': int.tryParse(json['aid']?.toString() ?? '') ?? 0,
                'security': json['scy']?.toString() ?? 'auto',
              },
            ],
          },
        ],
      },
      'streamSettings': _xrayStreamSettings(params, server, options),
    };
    _maybeApplyXrayMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseXrayShadowsocks(String link) {
    final uri = Uri.parse(link);
    final methodPassword = uri.userInfo.split(':');
    if (methodPassword.length != 2 || uri.host.isEmpty) {
      throw ConfigParserException('Invalid shadowsocks link');
    }
    return {
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {
            'address': uri.host,
            'port': uri.port > 0 ? uri.port : 8388,
            'method': methodPassword[0],
            'password': methodPassword[1],
          },
        ],
      },
    };
  }

  static Map<String, dynamic> _parseSingboxVless(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final server = uri.host;
    if (uuid.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid vless link');
    }
    final params = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'uuid': uuid,
      if (params['flow']?.isNotEmpty == true) 'flow': params['flow'],
      ..._singboxTls(params, server, options),
      ..._singboxTransport(params),
    };
    _maybeApplySingboxMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxTrojan(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'password': password,
      ..._singboxTls(uri.queryParameters, server, options),
      ..._singboxTransport(uri.queryParameters),
    };
    _maybeApplySingboxMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxVmess(
    String link, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final encoded = link.substring('vmess://'.length);
    final decoded = utf8.decode(base64.decode(_padBase64(encoded)));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final server = json['add']?.toString();
    final uuid = json['id']?.toString();
    if (server == null || uuid == null) {
      throw ConfigParserException('Invalid vmess link');
    }
    final params = <String, String>{
      if (json['net'] != null) 'type': json['net'].toString(),
      if (json['tls']?.toString() == 'tls') 'security': 'tls',
      if (json['sni'] != null) 'sni': json['sni'].toString(),
      if (json['host'] != null) 'host': json['host'].toString(),
      if (json['path'] != null) 'path': json['path'].toString(),
    };
    final outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': 'proxy',
      'server': server,
      'server_port': int.tryParse(json['port']?.toString() ?? '') ?? 443,
      'uuid': uuid,
      'alter_id': int.tryParse(json['aid']?.toString() ?? '') ?? 0,
      'security': json['scy']?.toString() ?? 'auto',
      ..._singboxTls(params, server, options),
      ..._singboxTransport(params),
    };
    _maybeApplySingboxMux(outbound, options);
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxShadowsocks(String link) {
    final uri = Uri.parse(link);
    final methodPassword = uri.userInfo.split(':');
    if (methodPassword.length != 2 || uri.host.isEmpty) {
      throw ConfigParserException('Invalid shadowsocks link');
    }
    return {
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': uri.host,
      'server_port': uri.port > 0 ? uri.port : 8388,
      'method': methodPassword[0],
      'password': methodPassword[1],
    };
  }

  static Map<String, dynamic> _parseSingboxHysteria2(String link) {
    final normalized = link.replaceFirst(
      RegExp(r'^hysteria2://', caseSensitive: false),
      'hy2://',
    );
    final uri = Uri.parse(normalized);
    final server = uri.host;
    if (server.isEmpty) {
      throw ConfigParserException('Invalid hy2 link');
    }
    final params = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'password': uri.userInfo,
      'tls': _singboxMandatoryTls(params, server),
    };

    final obfsType = params['obfs'];
    if (obfsType != null && obfsType.isNotEmpty) {
      outbound['obfs'] = {
        'type': obfsType,
        if (params['obfs-password']?.isNotEmpty == true)
          'password': params['obfs-password'],
      };
    }
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxHysteria(String link) {
    final normalized = link.replaceFirst(
      RegExp(r'^hysteria://', caseSensitive: false),
      'hy://',
    );
    final uri = Uri.parse(normalized);
    final server = uri.host;
    if (server.isEmpty) {
      throw ConfigParserException('Invalid hysteria link');
    }
    final params = uri.queryParameters;
    final auth = uri.userInfo.isNotEmpty ? uri.userInfo : params['auth'];
    final outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      if (auth != null && auth.isNotEmpty) 'auth_str': auth,
      'tls': _singboxMandatoryTls(
        params,
        server,
        sniKeys: const ['sni', 'peer'],
      ),
    };

    final up = int.tryParse(params['upmbps'] ?? '');
    if (up != null) {
      outbound['up_mbps'] = up;
    }
    final down = int.tryParse(params['downmbps'] ?? '');
    if (down != null) {
      outbound['down_mbps'] = down;
    }
    if (params['obfs'] == 'xplus') {
      outbound['obfs'] = params['obfsParam'] ?? '';
    }
    if (params['protocol']?.isNotEmpty == true) {
      outbound['protocol'] = params['protocol'];
    }
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxTuic(String link) {
    final uri = Uri.parse(link);
    final server = uri.host;
    if (server.isEmpty) {
      throw ConfigParserException('Invalid tuic link');
    }
    final parts = uri.userInfo.split(':');
    final uuid = parts.isNotEmpty ? parts[0] : '';
    final password = parts.length > 1 ? parts.sublist(1).join(':') : '';
    final params = uri.queryParameters;
    return {
      'type': 'tuic',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'uuid': uuid,
      'password': password,
      if (params['congestion_control']?.isNotEmpty == true)
        'congestion_control': params['congestion_control'],
      if (params['udp_relay_mode']?.isNotEmpty == true)
        'udp_relay_mode': params['udp_relay_mode'],
      'tls': _singboxMandatoryTls(params, server),
    };
  }

  static Map<String, dynamic> _parseSingboxWireGuard(String link) {
    final uri = Uri.parse(link);
    final server = uri.host;
    if (server.isEmpty) {
      throw ConfigParserException('Invalid wireguard link');
    }
    final params = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'wireguard',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 51820,
      'private_key': uri.userInfo,
    };
    if (params['publickey']?.isNotEmpty == true) {
      outbound['peer_public_key'] = params['publickey'];
    }
    if (params['psk']?.isNotEmpty == true) {
      outbound['pre_shared_key'] = params['psk'];
    }
    if (params['address']?.isNotEmpty == true) {
      outbound['local_address'] = params['address']!
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList();
    }
    if (params['reserved']?.isNotEmpty == true) {
      final bytes = params['reserved']!
          .split(',')
          .map((v) => int.tryParse(v.trim()))
          .whereType<int>()
          .toList();
      if (bytes.isNotEmpty) {
        outbound['reserved'] = bytes;
      }
    }
    final mtu = int.tryParse(params['mtu'] ?? '');
    if (mtu != null) {
      outbound['mtu'] = mtu;
    }
    return outbound;
  }

  static Map<String, dynamic> _parseSingboxSsh(String link) {
    final uri = Uri.parse(link);
    final server = uri.host;
    if (server.isEmpty) {
      throw ConfigParserException('Invalid ssh link');
    }
    final parts = uri.userInfo.split(':');
    final user = parts.isNotEmpty ? parts[0] : '';
    final password = parts.length > 1 ? parts.sublist(1).join(':') : '';
    final params = uri.queryParameters;
    return {
      'type': 'ssh',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 22,
      'user': user,
      if (password.isNotEmpty) 'password': password,
      if (params['pk']?.isNotEmpty == true) 'private_key': params['pk'],
      if (params['pkp']?.isNotEmpty == true)
        'private_key_passphrase': params['pkp'],
      if (params['hk']?.isNotEmpty == true)
        'host_key': params['hk']!
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList(),
    };
  }

  static Map<String, dynamic> _xrayStreamSettings(
    Map<String, String> params,
    String server, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final network = params['type'] ?? 'tcp';
    final stream = <String, dynamic>{'network': network};
    final fingerprint = _resolveFingerprint(params, options);

    final security = params['security'];
    if (security == 'reality') {
      stream['security'] = 'reality';
      stream['realitySettings'] = {
        'serverName': params['sni'] ?? server,
        'publicKey': params['pbk'] ?? '',
        'shortId': params['sid'] ?? '',
        'fingerprint': fingerprint,
      };
    } else if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      stream['security'] = 'tls';
      stream['tlsSettings'] = {
        'serverName': params['sni'] ?? server,
        'fingerprint': fingerprint,
      };
    } else {
      stream['security'] = 'none';
    }

    switch (network) {
      case 'ws':
        stream['wsSettings'] = {
          'path': params['path'] ?? '/',
          if (params['host']?.isNotEmpty == true)
            'headers': {'Host': params['host']},
        };
      case 'grpc':
        stream['grpcSettings'] = {
          'serviceName': params['serviceName'] ?? 'grpc',
          if (params['authority']?.isNotEmpty == true)
            'authority': params['authority'],
        };
      case 'httpupgrade':
        stream['httpupgradeSettings'] = {
          'path': params['path'] ?? '/',
          if (params['host']?.isNotEmpty == true) 'host': params['host'],
        };
      case 'xhttp':
        final mode = params['mode'];
        final resolvedMode = (mode == null || mode.isEmpty || mode == 'auto')
            ? TransportPresets.defaultXhttpMode
            : mode;
        stream['xhttpSettings'] = {
          'path': params['path'] ?? '/',
          'mode': resolvedMode,
          if (params['host']?.isNotEmpty == true) 'host': params['host'],
        };
    }

    return stream;
  }

  static String _resolveFingerprint(
    Map<String, String> params,
    LinkBuildOptions options,
  ) {
    final fromLink = params['fp'];
    if (fromLink != null && fromLink.isNotEmpty) {
      return fromLink;
    }
    return options.fingerprint.wireValue;
  }

  static void _maybeApplyXrayMux(
    Map<String, dynamic> outbound,
    LinkBuildOptions options,
  ) {
    if (!options.muxEnabled) {
      return;
    }
    outbound['mux'] = {
      'enabled': true,
      'concurrency': options.muxConcurrency,
    };
  }

  static void _maybeApplySingboxMux(
    Map<String, dynamic> outbound,
    LinkBuildOptions options,
  ) {
    if (!options.muxEnabled) {
      return;
    }
    outbound['multiplex'] = {
      'enabled': true,
      'max_connections': options.muxConcurrency,
    };
  }

  static Map<String, dynamic> _singboxTls(
    Map<String, String> params,
    String server, [
    LinkBuildOptions options = const LinkBuildOptions(),
  ]) {
    final fingerprint = _resolveFingerprint(params, options);
    final security = params['security'];
    if (security == 'reality') {
      return {
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? server,
          'reality': {
            'enabled': true,
            'public_key': params['pbk'] ?? '',
            'short_id': params['sid'] ?? '',
          },
          'utls': {'enabled': true, 'fingerprint': fingerprint},
        },
      };
    }
    if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      return {
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? server,
          'utls': {'enabled': true, 'fingerprint': fingerprint},
        },
      };
    }
    return {};
  }

  /// TLS block always enabled (Hysteria / TUIC).
  static Map<String, dynamic> _singboxMandatoryTls(
    Map<String, String> params,
    String server, {
    List<String> sniKeys = const ['sni'],
  }) {
    String? sni;
    for (final key in sniKeys) {
      final value = params[key];
      if (value != null && value.isNotEmpty) {
        sni = value;
        break;
      }
    }
    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': sni ?? server,
    };
    if (_truthyParam(params['insecure']) ||
        _truthyParam(params['allowInsecure'])) {
      tls['insecure'] = true;
    }
    final alpn = params['alpn'];
    if (alpn != null && alpn.isNotEmpty) {
      tls['alpn'] = alpn
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList();
    }
    return tls;
  }

  static bool _truthyParam(String? value) {
    if (value == null) {
      return false;
    }
    final lower = value.toLowerCase();
    return lower == '1' || lower == 'true' || lower == 'yes';
  }

  static Map<String, dynamic> _singboxTransport(Map<String, String> params) {
    final network = params['type'] ?? 'tcp';
    switch (network) {
      case 'ws':
        return {
          'transport': {
            'type': 'ws',
            'path': params['path'] ?? '/',
            if (params['host']?.isNotEmpty == true)
              'headers': {'Host': params['host']},
          },
        };
      case 'grpc':
        return {
          'transport': {
            'type': 'grpc',
            'service_name': params['serviceName'] ?? 'grpc',
          },
        };
      case 'httpupgrade':
        return {
          'transport': {
            'type': 'httpupgrade',
            'path': params['path'] ?? '/',
            if (params['host']?.isNotEmpty == true) 'host': params['host'],
          },
        };
      case 'xhttp':
        final mode = params['mode'];
        final resolvedMode = (mode == null || mode.isEmpty || mode == 'auto')
            ? TransportPresets.defaultXhttpMode
            : mode;
        return {
          'transport': {
            'type': 'xhttp',
            'path': params['path'] ?? '/',
            'mode': resolvedMode,
            if (params['host']?.isNotEmpty == true) 'host': params['host'],
          },
        };
      default:
        return {};
    }
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }
}
