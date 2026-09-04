import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dns_settings.dart';
const dnsSettingsStorageKey = 'dns_settings_v1';
class DnsSettingsStore {
  DnsSettingsStore._();
  static Future<DnsSettings> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(dnsSettingsStorageKey);
    if (raw == null) return const DnsSettings();
    try { final d = jsonDecode(raw); if (d is Map<String, dynamic>) return DnsSettings.fromJson(d); } catch (_) {}
    return const DnsSettings();
  }
  static Future<void> save(DnsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dnsSettingsStorageKey, jsonEncode(settings.toJson()));
    await prefs.setStringList('dns_system_servers', settings.systemDnsServerIps());
  }
}
final dnsSettingsProvider = StateNotifierProvider<DnsSettingsNotifier, DnsSettings>((ref) => DnsSettingsNotifier());
class DnsSettingsNotifier extends StateNotifier<DnsSettings> {
  DnsSettingsNotifier() : super(const DnsSettings()) { _load(); }
  Future<void> _load() async => state = await DnsSettingsStore.load();
  Future<void> updateSettings(DnsSettings s) async { state = s; await DnsSettingsStore.save(s); }
  Future<void> setMode(DnsMode mode) => updateSettings(state.copyWith(mode: mode));
  Future<void> setLeakProtection(bool e) => updateSettings(state.copyWith(leakProtectionEnabled: e));
  Future<void> addCustomUpstream(DnsUpstream u) => updateSettings(state.copyWith(upstreams: [...state.upstreams, u]));
  Future<void> removeCustomUpstreamAt(int i) { if (i < 0 || i >= state.upstreams.length) return Future.value(); final u = List<DnsUpstream>.from(state.upstreams)..removeAt(i); return updateSettings(state.copyWith(upstreams: u)); }
}
