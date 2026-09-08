import 'dart:convert';

/// AmneziaWG (AWG) link parsing and sing-box outbound helpers.
class AmneziaWgConfig {
  AmneziaWgConfig._();

  static const docsPath = 'docs/en/censorship_resistance.md#amneziawg';

  static const awgQueryKeys = [
    'jc', 'jmin', 'jmax', 's1', 's2', 's3', 's4',
    'h1', 'h2', 'h3', 'h4', 'i1', 'i2', 'i3', 'i4', 'i5', 'id', 'ip', 'ib',
  ];

  static const awgOutboundKeys = awgQueryKeys;
  static const defaultAwgMtu = 1280;

  static bool isAwgScheme(String scheme) => scheme.toLowerCase() == 'awg';

  static bool linkHasAwgParams(Map<String, String> params) {
    for (final key in awgQueryKeys) {
      for (final entry in params.entries) {
        if (entry.key.toLowerCase() == key && entry.value.trim().isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  static bool outboundHasAwgFields(Map<String, dynamic> outbound) {
    for (final key in awgOutboundKeys) {
      if (outbound.containsKey(key) && outbound[key] != null) return true;
    }
    final awg = outbound['awg'];
    return (awg is List && awg.isNotEmpty) || (awg is Map && awg.isNotEmpty);
  }

  static bool contentUsesAwg(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('awg://')) return true;
    if (lower.startsWith('wg://') || lower.startsWith('wireguard://')) {
      try {
        if (linkHasAwgParams(Uri.parse(trimmed).queryParameters)) return true;
      } catch (_) {}
    }
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return configUsesAwg(decoded);
      } catch (_) {}
    }
    return false;
  }

  static bool configUsesAwg(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) return false;
    for (final raw in outbounds) {
      if (raw is! Map) continue;
      final outbound = Map<String, dynamic>.from(raw);
      if (outbound['type']?.toString().toLowerCase() == 'wireguard' &&
          outboundHasAwgFields(outbound)) {
        return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> parseAwgFields(Map<String, String> params) {
    final fields = <String, dynamic>{};
    for (final canonical in awgQueryKeys) {
      for (final entry in params.entries) {
        if (entry.key.toLowerCase() != canonical) continue;
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        if (canonical.startsWith('i') || canonical == 'id' || canonical == 'ip' || canonical == 'ib') {
          fields[canonical] = value;
          continue;
        }
        if (canonical.startsWith('h')) {
          final parsed = _parseHeaderValue(value);
          if (parsed != null) fields[canonical] = parsed;
          continue;
        }
        final number = int.tryParse(value);
        if (number != null) fields[canonical] = number;
      }
    }
    return fields;
  }

  static dynamic _parseHeaderValue(String value) {
    final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(value.trim());
    if (range != null) return '${range.group(1)}-${range.group(2)}';
    return int.tryParse(value);
  }

  static int clampAwgMtu(int? mtu) {
    if (mtu == null || mtu <= 0) return defaultAwgMtu;
    return mtu > defaultAwgMtu ? defaultAwgMtu : mtu;
  }

  static Map<String, dynamic> buildSingboxOutbound({
    required String server,
    required int port,
    required String privateKey,
    required String publicKey,
    Map<String, String> params = const {},
    bool forceAwg = false,
  }) {
    final awgFields = parseAwgFields(params);
    final isAwg = forceAwg || awgFields.isNotEmpty;
    final mtu = isAwg ? clampAwgMtu(int.tryParse(params['mtu'] ?? '')) : int.tryParse(params['mtu'] ?? '');
    final peer = <String, dynamic>{
      'address': server,
      'port': port,
      'public_key': publicKey,
      'allowed_ips': _splitList(params['allowedips'] ?? '0.0.0.0/0,::/0'),
    };
    final psk = params['psk'] ?? params['presharedkey'];
    if (psk != null && psk.isNotEmpty) peer['pre_shared_key'] = psk;
    final reserved = _parseReserved(params['reserved']);
    if (reserved != null) peer['reserved'] = reserved;
    final keepalive = int.tryParse(params['keepalive'] ?? params['persistent_keepalive'] ?? '');
    if (keepalive != null && keepalive > 0) peer['persistent_keepalive_interval'] = keepalive;

    if (isAwg) {
      final outbound = <String, dynamic>{
        'type': 'wireguard', 'tag': 'proxy', 'mtu': mtu ?? defaultAwgMtu,
        'private_key': privateKey, 'peers': [peer], ...awgFields,
      };
      final address = params['address'];
      if (address != null && address.isNotEmpty) outbound['address'] = _splitList(address);
      return outbound;
    }

    final outbound = <String, dynamic>{
      'type': 'wireguard', 'tag': 'proxy', 'server': server,
      'server_port': port, 'private_key': privateKey,
    };
    if (publicKey.isNotEmpty) outbound['peer_public_key'] = publicKey;
    if (mtu != null) outbound['mtu'] = mtu;
    if (psk != null && psk.isNotEmpty) outbound['pre_shared_key'] = psk;
    final address = params['address'];
    if (address != null && address.isNotEmpty) outbound['local_address'] = _splitList(address);
    if (reserved != null) outbound['reserved'] = reserved;
    return outbound;
  }

  static void normalizeSingboxOutbound(Map<String, dynamic> outbound) {
    if (outbound['type']?.toString().toLowerCase() != 'wireguard' || !outboundHasAwgFields(outbound)) return;
    final mtu = outbound['mtu'];
    outbound['mtu'] = mtu is num ? clampAwgMtu(mtu.toInt()) : defaultAwgMtu;
  }

  static String unsupportedCoreMessage() =>
      'AmneziaWG obfuscation is not supported by the bundled official sing-box core. '
      'Use VLESS+XHTTP or mux fallback stacks, or see $docsPath';

  static List<String> _splitList(String value) =>
      value.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  static List<int>? _parseReserved(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final bytes = raw.split(',').map((p) => int.tryParse(p.trim())).whereType<int>().toList();
    return bytes.isEmpty ? null : bytes;
  }
}
