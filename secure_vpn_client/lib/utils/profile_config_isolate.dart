import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/routing_rule.dart';
import '../models/vpn_engine.dart';
import 'config_enhancer.dart';
import 'link_config_builder.dart';

/// Input for [buildProfileConfigInIsolate] (must be JSON-serializable).
class ProfileConfigIsolateInput {
  const ProfileConfigIsolateInput({
    required this.raw,
    required this.profileJson,
    required this.engineCoreName,
    required this.customRulesJson,
  });

  final String raw;
  final Map<String, dynamic> profileJson;
  final String engineCoreName;
  final List<Map<String, dynamic>> customRulesJson;
}

/// Builds final profile JSON off the UI isolate (link/JSON subscription content).
String buildProfileConfigInIsolate(ProfileConfigIsolateInput input) {
  final profile = Profile.fromJson(input.profileJson);
  final engine = VpnEngine.values.firstWhere(
    (candidate) => candidate.coreName == input.engineCoreName,
    orElse: () => VpnEngine.xray,
  );
  final customRules = input.customRulesJson
      .map((json) => RoutingRule.fromJson(json))
      .where((rule) => rule.enabled)
      .toList(growable: false);

  final raw = input.raw;
  String jsonConfig;
  if (raw.startsWith('{')) {
    jsonConfig = raw;
  } else if (raw.startsWith('[')) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    if (decoded.isEmpty || decoded.first is! Map) {
      throw StateError('Subscription JSON array is empty');
    }
    jsonConfig = jsonEncode(decoded.first);
  } else if (LinkConfigBuilder.isConfigLink(raw)) {
    jsonConfig = LinkConfigBuilder.buildFromLink(
      raw,
      engine,
      options: LinkBuildOptions.fromProfile(profile),
    );
  } else {
    throw StateError(
      'Unsupported profile content on desktop (expected JSON or share link)',
    );
  }

  final decoded = jsonDecode(jsonConfig);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Resolved config must be a JSON object');
  }

  return ConfigEnhancer.applyProfileSettings(
    jsonEncode(decoded),
    profile,
    engine,
    customRules: customRules,
  );
}

Future<String> buildProfileConfigOffUiThread({
  required String raw,
  required Profile profile,
  required VpnEngine engine,
  required List<RoutingRule> customRules,
}) {
  return compute(
    buildProfileConfigInIsolate,
    ProfileConfigIsolateInput(
      raw: raw,
      profileJson: profile.toJson(),
      engineCoreName: engine.coreName,
      customRulesJson: customRules.map((rule) => rule.toJson()).toList(),
    ),
  );
}
