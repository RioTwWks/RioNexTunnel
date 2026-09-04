import 'transport_preset.dart';

enum ProfileType { link, subscription }

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.configLink,
    this.type = ProfileType.link,
    this.selectedServerIndex = 0,
    this.selectedServerName,
    this.autoSelectBestServer = false,
    this.censorshipModeEnabled = false,
    this.transportPreset,
    this.tlsFingerprint = TlsFingerprint.firefox,
    this.muxEnabled = false,
    this.muxConcurrency = 8,
    this.ruDirectRouting = false,
    this.disableSocksInjection = false,
    this.multihopEnabled = false,
    this.hopServerIndices = const [],
  });

  final String id;
  final String name;
  final String configLink;
  final ProfileType type;
  final int selectedServerIndex;
  final String? selectedServerName;
  final bool autoSelectBestServer;
  final bool censorshipModeEnabled;
  final TransportPresetId? transportPreset;
  final TlsFingerprint tlsFingerprint;
  final bool muxEnabled;
  final int muxConcurrency;
  final bool ruDirectRouting;
  final bool disableSocksInjection;
  final bool multihopEnabled;
  final List<int> hopServerIndices;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'configLink': configLink,
    'type': type.name,
    'selectedServerIndex': selectedServerIndex,
    if (selectedServerName != null) 'selectedServerName': selectedServerName,
    'autoSelectBestServer': autoSelectBestServer,
    'censorshipModeEnabled': censorshipModeEnabled,
    if (transportPreset != null) 'transportPreset': transportPreset!.storageName,
    'tlsFingerprint': tlsFingerprint.wireValue,
    'muxEnabled': muxEnabled,
    'muxConcurrency': muxConcurrency,
    'ruDirectRouting': ruDirectRouting,
    'disableSocksInjection': disableSocksInjection,
    'multihopEnabled': multihopEnabled,
    'hopServerIndices': hopServerIndices,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    final presetRaw = json['transportPreset'] as String?;
    TransportPresetId? preset;
    if (presetRaw != null) {
      preset = TransportPresetId.values.firstWhere(
        (p) => p.storageName == presetRaw,
        orElse: () => TransportPresetId.xhttpReality,
      );
    }
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      configLink: json['configLink'] as String,
      type: ProfileType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ProfileType.link,
      ),
      selectedServerIndex: (json['selectedServerIndex'] as num?)?.toInt() ?? 0,
      selectedServerName: json['selectedServerName'] as String?,
      autoSelectBestServer: json['autoSelectBestServer'] as bool? ?? false,
      censorshipModeEnabled: json['censorshipModeEnabled'] as bool? ?? false,
      transportPreset: preset,
      tlsFingerprint: TlsFingerprintJson.fromWire(
        json['tlsFingerprint'] as String?,
      ),
      muxEnabled: json['muxEnabled'] as bool? ?? false,
      muxConcurrency: (json['muxConcurrency'] as num?)?.toInt() ?? 8,
      ruDirectRouting: json['ruDirectRouting'] as bool? ?? false,
      disableSocksInjection: json['disableSocksInjection'] as bool? ?? false,
      multihopEnabled: json['multihopEnabled'] as bool? ?? false,
      hopServerIndices: (json['hopServerIndices'] as List<dynamic>?)?.map((value) => (value as num).toInt()).toList() ?? const [],
    );
  }

  Profile copyWith({
    String? id,
    String? name,
    String? configLink,
    ProfileType? type,
    int? selectedServerIndex,
    String? selectedServerName,
    bool clearSelectedServerName = false,
    bool? autoSelectBestServer,
    bool? censorshipModeEnabled,
    TransportPresetId? transportPreset,
    bool clearTransportPreset = false,
    TlsFingerprint? tlsFingerprint,
    bool? muxEnabled,
    int? muxConcurrency,
    bool? ruDirectRouting,
    bool? disableSocksInjection,
    bool? multihopEnabled,
    List<int>? hopServerIndices,
    bool clearHopServerIndices = false,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      configLink: configLink ?? this.configLink,
      type: type ?? this.type,
      selectedServerIndex: selectedServerIndex ?? this.selectedServerIndex,
      selectedServerName: clearSelectedServerName
          ? null
          : (selectedServerName ?? this.selectedServerName),
      autoSelectBestServer: autoSelectBestServer ?? this.autoSelectBestServer,
      censorshipModeEnabled:
          censorshipModeEnabled ?? this.censorshipModeEnabled,
      transportPreset: clearTransportPreset
          ? null
          : (transportPreset ?? this.transportPreset),
      tlsFingerprint: tlsFingerprint ?? this.tlsFingerprint,
      muxEnabled: muxEnabled ?? this.muxEnabled,
      muxConcurrency: muxConcurrency ?? this.muxConcurrency,
      ruDirectRouting: ruDirectRouting ?? this.ruDirectRouting,
      disableSocksInjection: disableSocksInjection ?? this.disableSocksInjection,
      multihopEnabled: multihopEnabled ?? this.multihopEnabled,
      hopServerIndices: clearHopServerIndices ? const [] : (hopServerIndices ?? this.hopServerIndices),
    );
  }
}
