import '../models/routing_rule.dart';
import '../models/vpn_engine.dart';

enum RoutingPresetId {
  ruDirect,
  blockedSitesOnly;

  String get displayName {
    switch (this) {
      case RoutingPresetId.ruDirect:
        return 'RU direct / rest proxy';
      case RoutingPresetId.blockedSitesOnly:
        return 'Blocked sites only';
    }
  }
}

class RoutingPresetRegistry {
  RoutingPresetRegistry._();
  static const List<RoutingPresetId> all = RoutingPresetId.values;

  static List<RoutingRule> rulesFor(RoutingPresetId preset) {
    switch (preset) {
      case RoutingPresetId.ruDirect:
        return const [
          RoutingRule(
            id: 'preset-ru-geosite',
            type: RoutingRuleType.geosite,
            values: ['ru'],
            outbound: RoutingOutboundAction.direct,
          ),
          RoutingRule(
            id: 'preset-ru-geoip',
            type: RoutingRuleType.geoip,
            values: ['ru'],
            outbound: RoutingOutboundAction.direct,
          ),
        ];
      case RoutingPresetId.blockedSitesOnly:
        return const [
          RoutingRule(
            id: 'preset-block-ads',
            type: RoutingRuleType.domain,
            values: ['domain:doubleclick.net'],
            outbound: RoutingOutboundAction.block,
          ),
        ];
    }
  }
}

class RoutingConfigBuilder {
  RoutingConfigBuilder._();

  static bool rulesRequireGeoAssets(Iterable<RoutingRule> rules) {
    for (final rule in rules) {
      if (!rule.enabled) continue;
      if (rule.type == RoutingRuleType.geosite ||
          rule.type == RoutingRuleType.geoip) {
        return true;
      }
    }
    return false;
  }

  static void mergeUserRulesIntoConfig(
    Map<String, dynamic> config,
    List<RoutingRule> userRules,
    VpnEngine engine,
  ) {
    final enabled = userRules.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return;

    if (engine == VpnEngine.xray) {
      final routing = config['routing'];
      final routingMap = routing is Map
          ? Map<String, dynamic>.from(routing)
          : <String, dynamic>{'domainStrategy': 'AsIs'};
      final existing = List<dynamic>.from(
        routingMap['rules'] as List<dynamic>? ?? const [],
      );
      routingMap['rules'] = [
        ...enabled.map(_toXrayRule),
        ...existing,
      ];
      config['routing'] = routingMap;
      return;
    }

    final route = config['route'];
    final routeMap = route is Map
        ? Map<String, dynamic>.from(route)
        : <String, dynamic>{'final': 'proxy'};
    final existing = List<dynamic>.from(
      routeMap['rules'] as List<dynamic>? ?? const [],
    );
    routeMap['rules'] = [...enabled.map(_toSingboxRule), ...existing];
    routeMap.putIfAbsent('final', () => 'proxy');
    config['route'] = routeMap;
  }

  static Map<String, dynamic> _toXrayRule(RoutingRule rule) {
    final tag = rule.outbound.name;
    switch (rule.type) {
      case RoutingRuleType.domain:
        return {
          'type': 'field',
          'domain': rule.values,
          'outboundTag': tag == 'block' ? 'block' : tag,
        };
      case RoutingRuleType.ipCidr:
        return {'type': 'field', 'ip': rule.values, 'outboundTag': tag};
      case RoutingRuleType.geosite:
        return {
          'type': 'field',
          'domain': rule.values.map((v) => 'geosite:$v').toList(),
          'outboundTag': tag,
        };
      case RoutingRuleType.geoip:
        return {
          'type': 'field',
          'ip': rule.values.map((v) => 'geoip:$v').toList(),
          'outboundTag': tag,
        };
    }
  }

  static Map<String, dynamic> _toSingboxRule(RoutingRule rule) {
    if (rule.outbound == RoutingOutboundAction.block) {
      return {'domain': rule.values, 'action': 'reject'};
    }
    return {'domain': rule.values, 'outbound': rule.outbound.name};
  }
}
