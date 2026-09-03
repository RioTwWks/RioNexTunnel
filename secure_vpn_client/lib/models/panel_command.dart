/// Remote command pushed from RioNexGate panel (§2.4).
enum PanelCommandType {
  refreshConfig,
  disconnect,
  switchServer,
  unknown,
}

class PanelCommand {
  const PanelCommand({
    required this.seq,
    required this.type,
    this.payload = const {},
  });

  final int seq;
  final PanelCommandType type;
  final Map<String, dynamic> payload;

  int? get serverIndex {
    final raw = payload['server_index'] ??
        payload['serverIndex'] ??
        payload['index'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  String? get serverName {
    final raw = payload['server_name'] ?? payload['serverName'] ?? payload['name'];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }
}

/// Parses panel command JSON from WebSocket frames or long-poll bodies.
class PanelCommandParser {
  const PanelCommandParser._();

  static List<PanelCommand> parsePayload(dynamic decoded) {
    if (decoded == null) {
      return const [];
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => parseOne(Map<String, dynamic>.from(item)))
          .whereType<PanelCommand>()
          .toList();
    }
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final nested = map['commands'] ?? map['items'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => parseOne(Map<String, dynamic>.from(item)))
            .whereType<PanelCommand>()
            .toList();
      }
      final single = parseOne(map);
      return single == null ? const [] : [single];
    }
    return const [];
  }

  static PanelCommand? parseOne(Map<String, dynamic> map) {
    final rawType = map['command'] ?? map['type'] ?? map['action'];
    if (rawType is! String || rawType.trim().isEmpty) {
      return null;
    }

    final seqRaw = map['seq'] ?? map['sequence'] ?? map['id'];
    final seq = switch (seqRaw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };

    final payloadRaw = map['payload'] ?? map['data'] ?? map['params'];
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};

    return PanelCommand(
      seq: seq,
      type: _parseType(rawType.trim()),
      payload: payload,
    );
  }

  static PanelCommandType _parseType(String raw) {
    switch (raw.toLowerCase()) {
      case 'refresh_config':
      case 'refreshconfig':
        return PanelCommandType.refreshConfig;
      case 'disconnect':
        return PanelCommandType.disconnect;
      case 'switch_server':
      case 'switchserver':
        return PanelCommandType.switchServer;
      default:
        return PanelCommandType.unknown;
    }
  }
}
