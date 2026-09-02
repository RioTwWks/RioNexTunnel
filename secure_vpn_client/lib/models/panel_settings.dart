class PanelSettings {
  const PanelSettings({
    this.panelUrl,
    this.deviceToken,
    this.subscriptionUrl,
    this.configHash,
    this.enabled = false,
    this.lastSyncAt,
    this.lastError,
  });

  final String? panelUrl;
  final String? deviceToken;
  final String? subscriptionUrl;
  final String? configHash;
  final bool enabled;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get isConfigured =>
      enabled &&
      panelUrl != null &&
      panelUrl!.trim().isNotEmpty &&
      deviceToken != null &&
      deviceToken!.trim().isNotEmpty;

  PanelSettings copyWith({
    String? panelUrl,
    String? deviceToken,
    String? subscriptionUrl,
    String? configHash,
    bool? enabled,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearDeviceToken = false,
    bool clearSubscriptionUrl = false,
    bool clearConfigHash = false,
    bool clearLastSyncAt = false,
    bool clearLastError = false,
  }) {
    return PanelSettings(
      panelUrl: panelUrl ?? this.panelUrl,
      deviceToken: clearDeviceToken ? null : (deviceToken ?? this.deviceToken),
      subscriptionUrl: clearSubscriptionUrl
          ? null
          : (subscriptionUrl ?? this.subscriptionUrl),
      configHash: clearConfigHash ? null : (configHash ?? this.configHash),
      enabled: enabled ?? this.enabled,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
    'panelUrl': panelUrl,
    'deviceToken': deviceToken,
    'subscriptionUrl': subscriptionUrl,
    'configHash': configHash,
    'enabled': enabled,
    if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toUtc().toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };

  factory PanelSettings.fromJson(Map<String, dynamic> json) {
    final lastSyncRaw = json['lastSyncAt'] as String?;
    return PanelSettings(
      panelUrl: json['panelUrl'] as String?,
      deviceToken: json['deviceToken'] as String?,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      configHash: json['configHash'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      lastSyncAt: lastSyncRaw == null ? null : DateTime.tryParse(lastSyncRaw),
      lastError: json['lastError'] as String?,
    );
  }
}
