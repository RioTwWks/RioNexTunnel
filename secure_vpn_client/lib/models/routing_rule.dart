import 'package:uuid/uuid.dart';

enum RoutingRuleType {
  domain,
  ipCidr,
  geosite,
  geoip;

  String get displayName {
    switch (this) {
      case RoutingRuleType.domain:
        return 'Domain';
      case RoutingRuleType.ipCidr:
        return 'IP / CIDR';
      case RoutingRuleType.geosite:
        return 'Geosite';
      case RoutingRuleType.geoip:
        return 'GeoIP';
    }
  }

  static RoutingRuleType fromWire(String value) {
    return RoutingRuleType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => RoutingRuleType.domain,
    );
  }
}

enum RoutingOutboundAction {
  direct,
  proxy,
  block;

  String get displayName {
    switch (this) {
      case RoutingOutboundAction.direct:
        return 'Direct';
      case RoutingOutboundAction.proxy:
        return 'Proxy';
      case RoutingOutboundAction.block:
        return 'Block';
    }
  }

  static RoutingOutboundAction fromWire(String value) {
    return RoutingOutboundAction.values.firstWhere(
      (a) => a.name == value,
      orElse: () => RoutingOutboundAction.proxy,
    );
  }
}

class RoutingRule {
  const RoutingRule({
    required this.id,
    required this.type,
    required this.values,
    required this.outbound,
    this.name,
    this.enabled = true,
  });

  final String id;
  final String? name;
  final RoutingRuleType type;
  final List<String> values;
  final RoutingOutboundAction outbound;
  final bool enabled;

  RoutingRule copyWith({
    String? id,
    String? name,
    bool clearName = false,
    RoutingRuleType? type,
    List<String>? values,
    RoutingOutboundAction? outbound,
    bool? enabled,
  }) {
    return RoutingRule(
      id: id ?? this.id,
      name: clearName ? null : (name ?? this.name),
      type: type ?? this.type,
      values: values ?? this.values,
      outbound: outbound ?? this.outbound,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null && name!.isNotEmpty) 'name': name,
    'type': type.name,
    'values': values,
    'outbound': outbound.name,
    'enabled': enabled,
  };

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final values = rawValues is List
        ? rawValues.map((v) => v.toString().trim()).where((v) => v.isNotEmpty).toList()
        : <String>[];
    return RoutingRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String?,
      type: RoutingRuleType.fromWire(json['type'] as String? ?? 'domain'),
      values: values,
      outbound: RoutingOutboundAction.fromWire(
        json['outbound'] as String? ?? 'proxy',
      ),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class RoutingRuleSet {
  const RoutingRuleSet({this.rules = const [], this.version = 1});

  final int version;
  final List<RoutingRule> rules;

  List<RoutingRule> get enabledRules =>
      rules.where((rule) => rule.enabled).toList(growable: false);

  RoutingRuleSet copyWith({List<RoutingRule>? rules, int? version}) {
    return RoutingRuleSet(
      rules: rules ?? this.rules,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'rules': rules.map((r) => r.toJson()).toList(),
  };

  factory RoutingRuleSet.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'];
    final rules = rawRules is List
        ? rawRules
              .whereType<Map>()
              .map((r) => RoutingRule.fromJson(Map<String, dynamic>.from(r)))
              .toList()
        : <RoutingRule>[];
    return RoutingRuleSet(
      version: (json['version'] as num?)?.toInt() ?? 1,
      rules: rules,
    );
  }
}
