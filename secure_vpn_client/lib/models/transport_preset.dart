/// Transport stack presets for censorship-resistant connections.
enum TransportPresetId {
  /// Raw TCP with TLS (least obfuscated; use only when server requires it).
  plainTls,

  /// WebSocket over TLS — common CDN-friendly transport.
  wsTls,

  /// gRPC over TLS — HTTP/2 multiplexing, good for some DPI environments.
  grpcTls,

  /// HTTPUpgrade over TLS — mimics HTTP upgrade handshake.
  httpUpgradeTls,

  /// VLESS/Trojan with REALITY (xray) — SNI camouflage without real cert.
  reality,

  /// VLESS + REALITY + XHTTP (recommended 2026 stack for RU DPI).
  xhttpReality,
}

/// uTLS ClientHello fingerprint choices.
enum TlsFingerprint {
  firefox,
  edge,
  chrome,
  safari,
  random,
}

extension TlsFingerprintJson on TlsFingerprint {
  String get wireValue => name;

  static TlsFingerprint fromWire(String? value) {
    if (value == null || value.isEmpty) {
      return TlsFingerprint.firefox;
    }
    return TlsFingerprint.values.firstWhere(
      (f) => f.name == value.toLowerCase(),
      orElse: () => TlsFingerprint.firefox,
    );
  }
}

extension TransportPresetIdLabels on TransportPresetId {
  String get label => switch (this) {
        TransportPresetId.plainTls => 'Plain TLS',
        TransportPresetId.wsTls => 'WebSocket + TLS',
        TransportPresetId.grpcTls => 'gRPC + TLS',
        TransportPresetId.httpUpgradeTls => 'HTTPUpgrade + TLS',
        TransportPresetId.reality => 'REALITY',
        TransportPresetId.xhttpReality => 'XHTTP + REALITY',
      };

  String get shortLabel => switch (this) {
        TransportPresetId.plainTls => 'TLS',
        TransportPresetId.wsTls => 'WS',
        TransportPresetId.grpcTls => 'gRPC',
        TransportPresetId.httpUpgradeTls => 'HTTPUp',
        TransportPresetId.reality => 'REALITY',
        TransportPresetId.xhttpReality => 'XHTTP',
      };

  String get description => switch (this) {
        TransportPresetId.plainTls =>
          'TCP with TLS. Easiest to fingerprint; use only if the server has no other transport.',
        TransportPresetId.wsTls =>
          'WebSocket inside TLS. Works well behind CDNs and reverse proxies.',
        TransportPresetId.grpcTls =>
          'gRPC (HTTP/2) inside TLS. Useful when WebSocket is throttled.',
        TransportPresetId.httpUpgradeTls =>
          'HTTP Upgrade handshake inside TLS. Alternative to WebSocket on some networks.',
        TransportPresetId.reality =>
          'REALITY camouflage (xray). Hides proxy behind a real site TLS fingerprint.',
        TransportPresetId.xhttpReality =>
          'XHTTP + REALITY — preferred 2026 stack against modern DPI (stream-one mode).',
      };

  String get storageName => name;
}

/// Result of auto-detecting transport from a share link or JSON snippet.
class DetectedTransport {
  const DetectedTransport({
    required this.preset,
    this.security,
    this.network,
    this.fingerprint,
    this.hasMux = false,
    this.xhttpMode,
  });

  final TransportPresetId preset;
  final String? security;
  final String? network;
  final String? fingerprint;
  final bool hasMux;
  final String? xhttpMode;

  String get stackSummary {
    final parts = <String>[
      preset.shortLabel,
      if (security != null && security!.isNotEmpty) security!,
      if (fingerprint != null && fingerprint!.isNotEmpty) fingerprint!,
    ];
    return parts.join(' · ');
  }
}
