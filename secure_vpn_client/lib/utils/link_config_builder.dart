import 'dart:convert';

import '../models/vpn_engine.dart';
import 'config_parser.dart';

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

  static String buildFromLink(String link, VpnEngine engine) {
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
        ? _buildSingbox(normalized)
        : _buildXray(normalized);
  }

  static String? _schemeOf(String value) {
    final trimmed = value.trim();
    final sep = trimmed.indexOf('://');
    if (sep <= 0) {
      return null;
    }
    return trimmed.substring(0, sep).toLowerCase();
  }

  static String _buildXray(String link) {
    final outbound = _parseXrayOutbound(link);
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

  static String _buildSingbox(String link) {
    final outbound = _parseSingboxOutbound(link);
    final config = {
      'log': {'level': 'warn'},
      // Never use type:local on Android VPN — system resolver hits [::1]:53
      // and fails while TUN is up. Bootstrap with IP DNS via direct.
      'dns': {
        'servers': [
          {'type': 'udp', 'tag': 'dns-direct', 'server': '8.8.8.8'},
          {'type': 'udp', 'tag': 'dns-backup', 'server': '1.1.1.1'},
        ],
        'final': 'dns-direct',
        'strategy': 'prefer_ipv4',
      },
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

  static Map<String, dynamic> _parseXrayOutbound(String link) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseXrayVless(link);
    }
    if (lower.startsWith('trojan://')) {
      return _parseXrayTrojan(link);
    }
    if (lower.startsWith('vmess://')) {
      return _parseXrayVmess(link);
    }
    if (lower.startsWith('ss://')) {
      return _parseXrayShadowsocks(link);
    }
    throw ConfigParserException('Unsupported Xray link');
  }

  static Map<String, dynamic> _parseSingboxOutbound(String link) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseSingboxVless(link);
    }
    if (lower.startsWith('trojan://')) {
      return _parseSingboxTrojan(link);
    }
    if (lower.startsWith('vmess://')) {
      return _parseSingboxVmess(link);
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

  static Map<String, dynamic> _parseXrayVless(String link) {
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
      'streamSettings': _xrayStreamSettings(params, server),
    };
    return outbound;
  }

  static Map<String, dynamic> _parseXrayTrojan(String link) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    final port = uri.port > 0 ? uri.port : 443;
    return {
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {'address': server, 'port': port, 'password': password},
        ],
      },
      'streamSettings': _xrayStreamSettings(uri.queryParameters, server),
    };
  }

  static Map<String, dynamic> _parseXrayVmess(String link) {
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
    return {
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
      'streamSettings': _xrayStreamSettings(params, server),
    };
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

  static Map<String, dynamic> _parseSingboxVless(String link) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final server = uri.host;
    if (uuid.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid vless link');
    }
    final params = uri.queryParameters;
    return {
      'type': 'vless',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'uuid': uuid,
      if (params['flow']?.isNotEmpty == true) 'flow': params['flow'],
      ..._singboxTls(params, server),
      ..._singboxTransport(params),
    };
  }

  static Map<String, dynamic> _parseSingboxTrojan(String link) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    return {
      'type': 'trojan',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'password': password,
      ..._singboxTls(uri.queryParameters, server),
      ..._singboxTransport(uri.queryParameters),
    };
  }

  static Map<String, dynamic> _parseSingboxVmess(String link) {
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
    return {
      'type': 'vmess',
      'tag': 'proxy',
      'server': server,
      'server_port': int.tryParse(json['port']?.toString() ?? '') ?? 443,
      'uuid': uuid,
      'alter_id': int.tryParse(json['aid']?.toString() ?? '') ?? 0,
      'security': json['scy']?.toString() ?? 'auto',
      ..._singboxTls(params, server),
      ..._singboxTransport(params),
    };
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
    String server,
  ) {
    final network = params['type'] ?? 'tcp';
    final stream = <String, dynamic>{'network': network};

    final security = params['security'];
    if (security == 'reality') {
      stream['security'] = 'reality';
      stream['realitySettings'] = {
        'serverName': params['sni'] ?? server,
        'publicKey': params['pbk'] ?? '',
        'shortId': params['sid'] ?? '',
        'fingerprint': params['fp'] ?? 'chrome',
      };
    } else if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      stream['security'] = 'tls';
      stream['tlsSettings'] = {
        'serverName': params['sni'] ?? server,
        if (params['fp']?.isNotEmpty == true) 'fingerprint': params['fp'],
        // Do not emit allowInsecure — removed in modern Xray (use pcs/vcn).
      };
    } else {
      stream['security'] = 'none';
    }

    if (network == 'ws') {
      stream['wsSettings'] = {
        'path': params['path'] ?? '/',
        if (params['host']?.isNotEmpty == true)
          'headers': {'Host': params['host']},
      };
    }

    return stream;
  }

  static Map<String, dynamic> _singboxTls(
    Map<String, String> params,
    String server,
  ) {
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
          if (params['fp']?.isNotEmpty == true)
            'utls': {'enabled': true, 'fingerprint': params['fp']},
        },
      };
    }
    if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      return {
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? server,
          if (params['fp']?.isNotEmpty == true)
            'utls': {'enabled': true, 'fingerprint': params['fp']},
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
    if (network == 'ws') {
      return {
        'transport': {
          'type': 'ws',
          'path': params['path'] ?? '/',
          if (params['host']?.isNotEmpty == true)
            'headers': {'Host': params['host']},
        },
      };
    }
    return {};
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }
}
