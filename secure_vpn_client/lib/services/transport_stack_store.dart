import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transport_stack.dart';

class TransportStackStore {
  TransportStackStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _storageKey = 'transport_stack_stats_v1';

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _entryKey({
    required String profileId,
    required String serverKey,
    required TransportStackKind kind,
  }) =>
      '$profileId|$serverKey|${kind.name}';

  Future<TransportStackStats?> load({
    required String profileId,
    required String serverKey,
    required TransportStackKind kind,
  }) async {
    await _ensurePrefs();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entry = decoded[_entryKey(
      profileId: profileId,
      serverKey: serverKey,
      kind: kind,
    )];
    if (entry is! Map) {
      return null;
    }
    return TransportStackStats.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<void> recordAttempt({
    required String profileId,
    required String serverKey,
    required TransportStackKind kind,
    required bool success,
    int? latencyMs,
  }) async {
    await _ensurePrefs();
    final existing = await load(
          profileId: profileId,
          serverKey: serverKey,
          kind: kind,
        ) ??
        const TransportStackStats();
    final updated = existing.recordAttempt(success: success, latencyMs: latencyMs);
    final raw = _prefs!.getString(_storageKey);
    final map = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map[_entryKey(profileId: profileId, serverKey: serverKey, kind: kind)] =
        updated.toJson();
    await _prefs!.setString(_storageKey, jsonEncode(map));
  }
}
