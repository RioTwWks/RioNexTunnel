import 'dart:convert';

import '../models/multihop_chain.dart';
import '../models/vpn_engine.dart';

class MultihopConfigException implements Exception {
  MultihopConfigException(this.message);
  final String message;
  @override
  String toString() => 'MultihopConfigException: $message';
}

class MultihopConfigBuilder {
  MultihopConfigBuilder._();
  static const exitTag = 'proxy';

  static Map<String, dynamic> build(
    List<Map<String, dynamic>> hopConfigs,
    VpnEngine engine,
  ) {
    if (hopConfigs.length < 2) {
      throw MultihopConfigException('Multihop requires at least 2 hop configs');
    }
    final chainedOutbounds = <Map<String, dynamic>>[];
    final hopCount = hopConfigs.length;
    for (var i = 0; i < hopCount; i++) {
      final proxy = _extractProxyOutbound(hopConfigs[i], engine);
      final isExit = i == hopCount - 1;
      MultihopChain.validateHopOutbound(proxy, isExit: isExit, hopPosition: i);
      final tag = isExit ? exitTag : 'hop-$i';
      proxy['tag'] = tag;
      if (i > 0) {
        final prevTag = 'hop-${i - 1}';
        if (engine == VpnEngine.xray) {
          proxy['proxySettings'] = {'tag': prevTag};
        } else {
          proxy['detour'] = prevTag;
        }
      }
      chainedOutbounds.add(proxy);
    }
    final base = Map<String, dynamic>.from(hopConfigs.last);
    base['outbounds'] = [...chainedOutbounds, ..._utilityOutbounds(hopConfigs.last, engine)];
    _normalizeRouting(base, engine, exitTag);
    return base;
  }

  static Map<String, dynamic> _extractProxyOutbound(
    Map<String, dynamic> config,
    VpnEngine engine,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      throw MultihopConfigException('Hop config is missing outbounds');
    }
    for (final raw in outbounds) {
      if (raw is! Map) continue;
      final outbound = Map<String, dynamic>.from(raw);
      if (_isProxyOutbound(outbound, engine)) {
        outbound.remove('proxySettings');
        outbound.remove('detour');
        return outbound;
      }
    }
    throw MultihopConfigException('Hop config has no proxy outbound');
  }

  static bool _isProxyOutbound(Map<String, dynamic> outbound, VpnEngine engine) {
    final protocol = outbound['protocol']?.toString();
    final type = outbound['type']?.toString();
    if (engine == VpnEngine.xray) {
      return protocol == 'vless' || protocol == 'vmess' || protocol == 'trojan' || protocol == 'shadowsocks';
    }
    return type == 'vless' || type == 'vmess' || type == 'trojan' || type == 'shadowsocks' ||
        type == 'hysteria' || type == 'hysteria2' || type == 'tuic' || type == 'wireguard' || type == 'ssh';
  }

  static List<Map<String, dynamic>> _utilityOutbounds(Map<String, dynamic> config, VpnEngine engine) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final raw in outbounds) {
      if (raw is! Map) continue;
      final outbound = Map<String, dynamic>.from(raw);
      if (_isUtilityOutbound(outbound, engine)) result.add(outbound);
    }
    return result;
  }

  static bool _isUtilityOutbound(Map<String, dynamic> outbound, VpnEngine engine) {
    if (engine == VpnEngine.xray) {
      final protocol = outbound['protocol']?.toString();
      return protocol == 'freedom' || protocol == 'blackhole' || protocol == 'dns';
    }
    final type = outbound['type']?.toString();
    return type == 'direct' || type == 'block' || type == 'dns';
  }

  static void _normalizeRouting(Map<String, dynamic> config, VpnEngine engine, String exitTag) {
    if (engine == VpnEngine.xray) {
      final routing = config['routing'];
      final routingMap = routing is Map ? Map<String, dynamic>.from(routing) : <String, dynamic>{'domainStrategy': 'AsIs'};
      final rules = List<dynamic>.from(routingMap['rules'] as List<dynamic>? ?? const []);
      routingMap['rules'] = rules.map((rule) {
        if (rule is! Map) return rule;
        final normalized = Map<String, dynamic>.from(rule);
        if (normalized['outboundTag'] == 'proxy') normalized['outboundTag'] = exitTag;
        return normalized;
      }).toList();
      config['routing'] = routingMap;
      return;
    }
    final route = config['route'];
    final routeMap = route is Map ? Map<String, dynamic>.from(route) : <String, dynamic>{'final': exitTag};
    if (routeMap['final'] == 'proxy') routeMap['final'] = exitTag;
    final rules = List<dynamic>.from(routeMap['rules'] as List<dynamic>? ?? const []);
    routeMap['rules'] = rules.map((rule) {
      if (rule is! Map) return rule;
      final normalized = Map<String, dynamic>.from(rule);
      if (normalized['outbound'] == 'proxy') normalized['outbound'] = exitTag;
      return normalized;
    }).toList();
    routeMap.putIfAbsent('final', () => exitTag);
    config['route'] = routeMap;
  }
}
