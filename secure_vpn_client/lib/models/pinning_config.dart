import 'dart:convert';

/// Opt-in SPKI certificate pinning for subscription HTTP fetch.
class PinningConfig {
  const PinningConfig({
    this.enabled = false,
    this.pinsByHost = const {},
  });

  static const disabled = PinningConfig();

  final bool enabled;

  /// Host (lowercase) → base64 SHA-256 SPKI hashes (no `sha256/` prefix).
  final Map<String, List<String>> pinsByHost;

  List<String>? pinsForHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final pins = pinsByHost[normalized];
    if (pins == null || pins.isEmpty) {
      return null;
    }
    return pins;
  }

  bool shouldPinHost(String host) =>
      enabled && (pinsForHost(host)?.isNotEmpty ?? false);

  PinningConfig copyWith({
    bool? enabled,
    Map<String, List<String>>? pinsByHost,
  }) {
    return PinningConfig(
      enabled: enabled ?? this.enabled,
      pinsByHost: pinsByHost ?? this.pinsByHost,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'pinsByHost': pinsByHost,
  };

  factory PinningConfig.fromJson(Map<String, dynamic> json) {
    final rawPins = json['pinsByHost'];
    final parsed = <String, List<String>>{};
    if (rawPins is Map) {
      for (final entry in rawPins.entries) {
        final host = entry.key.toString().trim().toLowerCase();
        if (host.isEmpty) {
          continue;
        }
        final values = entry.value;
        if (values is List) {
          final pins = values
              .map((value) => SubscriptionSpki.normalizePin(value.toString()))
              .where((pin) => pin.isNotEmpty)
              .toList(growable: false);
          if (pins.isNotEmpty) {
            parsed[host] = pins;
          }
        }
      }
    }
    return PinningConfig(
      enabled: json['enabled'] as bool? ?? false,
      pinsByHost: parsed,
    );
  }

  static PinningConfig fromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return PinningConfig.disabled;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PinningConfig.fromJson(decoded);
      }
    } catch (_) {
      // Ignore corrupt storage.
    }
    return PinningConfig.disabled;
  }

  String toStorageJson() => jsonEncode(toJson());
}

/// SPKI hash helpers shared by pinning config and HTTP client.
class SubscriptionSpki {
  SubscriptionSpki._();

  static String normalizePin(String input) {
    var trimmed = input.trim();
    if (trimmed.toLowerCase().startsWith('sha256/')) {
      trimmed = trimmed.substring('sha256/'.length).trim();
    }
    return trimmed;
  }

  static String displayPin(String normalizedPin) =>
      'sha256/${normalizePin(normalizedPin)}';

  static bool isValidPinFormat(String pin) {
    final normalized = normalizePin(pin);
    if (normalized.isEmpty) {
      return false;
    }
    try {
      final decoded = base64.decode(normalized);
      return decoded.length == 32;
    } catch (_) {
      return false;
    }
  }
}
