import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/routing_rule.dart';

const _routingRulesKey = 'custom_routing_rules_v1';

class RoutingRulesService {
  Future<RoutingRuleSet> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_routingRulesKey);
    if (raw == null || raw.isEmpty) return const RoutingRuleSet();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RoutingRuleSet.fromJson(decoded);
      }
    } catch (_) {}
    return const RoutingRuleSet();
  }

  Future<void> save(RoutingRuleSet ruleSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routingRulesKey, jsonEncode(ruleSet.toJson()));
  }
}
