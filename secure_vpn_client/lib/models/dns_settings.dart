/// Advanced DNS settings for RioNexTunnel (P2 Agent B).
enum DnsMode { defaultMode, custom, encrypted }
enum DnsUpstreamKind { udp, doh, dot }
class DnsUpstream {
  const DnsUpstream({required this.label, required this.kind, required this.address});
  final String label; final DnsUpstreamKind kind; final String address;
  static DnsUpstream? tryParse({required String label, required String raw}) {
    final trimmed = raw.trim(); if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('https://') || lower.startsWith('h3://')) return DnsUpstream(label: label, kind: DnsUpstreamKind.doh, address: trimmed);
    if (lower.startsWith('tls://')) return DnsUpstream(label: label, kind: DnsUpstreamKind.dot, address: trimmed.substring(6));
    if (_isIpv4(trimmed)) return DnsUpstream(label: label, kind: DnsUpstreamKind.udp, address: trimmed);
    if (trimmed.contains('.') && !trimmed.contains('/')) return DnsUpstream(label: label, kind: DnsUpstreamKind.dot, address: trimmed);
    return null;
  }
  static bool _isIpv4(String value) {
    final parts = value.split('.'); if (parts.length != 4) return false;
    for (final part in parts) { final n = int.tryParse(part); if (n == null || n < 0 || n > 255) return false; }
    return true;
  }
  Map<String, dynamic> toJson() => {'label': label, 'kind': kind.name, 'address': address};
  factory DnsUpstream.fromJson(Map<String, dynamic> json) => DnsUpstream(
    label: json['label']?.toString() ?? 'Resolver',
    kind: DnsUpstreamKind.values.firstWhere((k) => k.name == (json['kind']?.toString() ?? 'udp'), orElse: () => DnsUpstreamKind.udp),
    address: json['address']?.toString() ?? '',
  );
}
class DnsSettings {
  const DnsSettings({this.mode = DnsMode.defaultMode, this.upstreams = const [], this.leakProtectionEnabled = true});
  final DnsMode mode; final List<DnsUpstream> upstreams; final bool leakProtectionEnabled;
  static const encryptedPresets = <DnsUpstream>[
    DnsUpstream(label: 'Cloudflare DoH', kind: DnsUpstreamKind.doh, address: 'https://cloudflare-dns.com/dns-query'),
    DnsUpstream(label: 'Google DoH', kind: DnsUpstreamKind.doh, address: 'https://dns.google/dns-query'),
    DnsUpstream(label: 'Quad9 DoT', kind: DnsUpstreamKind.dot, address: '9.9.9.9'),
  ];
  static const defaultUdpUpstreams = <DnsUpstream>[
    DnsUpstream(label: 'Google', kind: DnsUpstreamKind.udp, address: '8.8.8.8'),
    DnsUpstream(label: 'Cloudflare', kind: DnsUpstreamKind.udp, address: '1.1.1.1'),
  ];
  List<DnsUpstream> effectiveUpstreams() {
    switch (mode) {
      case DnsMode.defaultMode: return defaultUdpUpstreams;
      case DnsMode.encrypted: return upstreams.isEmpty ? encryptedPresets : upstreams;
      case DnsMode.custom: return upstreams.isEmpty ? defaultUdpUpstreams : upstreams;
    }
  }
  List<String> systemDnsServerIps() {
    final ips = <String>[];
    for (final u in effectiveUpstreams()) {
      if (u.kind == DnsUpstreamKind.udp || (u.kind == DnsUpstreamKind.dot && DnsUpstream._isIpv4(u.address))) ips.add(u.address);
    }
    return ips.isEmpty ? ['8.8.8.8', '1.1.1.1'] : ips;
  }
  Map<String, dynamic> toJson() => {'mode': mode.name, 'upstreams': upstreams.map((u) => u.toJson()).toList(), 'leakProtectionEnabled': leakProtectionEnabled};
  factory DnsSettings.fromJson(Map<String, dynamic> json) => DnsSettings(
    mode: DnsMode.values.firstWhere((m) => m.name == (json['mode']?.toString() ?? 'defaultMode'), orElse: () => DnsMode.defaultMode),
    upstreams: (json['upstreams'] as List<dynamic>? ?? const []).whereType<Map>().map((e) => DnsUpstream.fromJson(Map<String, dynamic>.from(e))).where((u) => u.address.isNotEmpty).toList(),
    leakProtectionEnabled: json['leakProtectionEnabled'] as bool? ?? true,
  );
  DnsSettings copyWith({DnsMode? mode, List<DnsUpstream>? upstreams, bool? leakProtectionEnabled}) => DnsSettings(mode: mode ?? this.mode, upstreams: upstreams ?? this.upstreams, leakProtectionEnabled: leakProtectionEnabled ?? this.leakProtectionEnabled);
}
