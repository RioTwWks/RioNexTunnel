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
  });

  final String id;
  final String name;
  final String configLink;
  final ProfileType type;

  /// Index into the subscription's non-decoy server list (subscriptions only).
  final int selectedServerIndex;

  /// Last known display name for [selectedServerIndex] (optional cache).
  final String? selectedServerName;

  /// When true, [VpnService.connect] probes latency and picks the best node.
  final bool autoSelectBestServer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'configLink': configLink,
    'type': type.name,
    'selectedServerIndex': selectedServerIndex,
    if (selectedServerName != null) 'selectedServerName': selectedServerName,
    'autoSelectBestServer': autoSelectBestServer,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
