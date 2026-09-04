import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/routing_rule.dart';
import '../services/routing_rules_service.dart';
import '../utils/routing_config_builder.dart';

final routingRulesServiceProvider = Provider<RoutingRulesService>((ref) {
  return RoutingRulesService();
});

final routingRulesProvider =
    StateNotifierProvider<RoutingRulesNotifier, RoutingRuleSet>((ref) {
      return RoutingRulesNotifier(ref.watch(routingRulesServiceProvider));
    });

class RoutingRulesNotifier extends StateNotifier<RoutingRuleSet> {
  RoutingRulesNotifier(this._service) : super(const RoutingRuleSet()) {
    _load();
  }

  final RoutingRulesService _service;

  Future<void> _load() async => state = await _service.load();

  Future<void> replaceAll(List<RoutingRule> rules) async {
    state = RoutingRuleSet(rules: rules);
    await _service.save(state);
  }

  Future<void> addRule(RoutingRule rule) async {
    state = state.copyWith(rules: [...state.rules, rule]);
    await _service.save(state);
  }

  Future<void> updateRule(RoutingRule rule) async {
    state = state.copyWith(
      rules: state.rules.map((r) => r.id == rule.id ? rule : r).toList(),
    );
    await _service.save(state);
  }

  Future<void> removeRule(String id) async {
    state = state.copyWith(rules: state.rules.where((r) => r.id != id).toList());
    await _service.save(state);
  }

  Future<void> toggleRule(String id, bool enabled) async {
    state = state.copyWith(
      rules: state.rules
          .map((r) => r.id == id ? r.copyWith(enabled: enabled) : r)
          .toList(),
    );
    await _service.save(state);
  }

  Future<void> applyPreset(RoutingPresetId preset) async {
    await replaceAll([
      ...RoutingPresetRegistry.rulesFor(preset),
      ...state.rules,
    ]);
  }

  Future<void> importFromJson(String jsonText) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Routing import must be a JSON object');
    }
    final imported = RoutingRuleSet.fromJson(decoded);
    if (imported.rules.isEmpty) {
      throw const FormatException('No routing rules found');
    }
    await replaceAll(imported.rules);
  }

  RoutingRule createEmptyRule() => RoutingRule(
    id: const Uuid().v4(),
    type: RoutingRuleType.domain,
    values: const [],
    outbound: RoutingOutboundAction.proxy,
  );
}
