/// Represents an installed application on the device
class AppInfo {
  /// Package name of the app
  final String packageName;

  /// Display name of the app
  final String name;

  /// Whether this is a system app
  final bool isSystemApp;

  /// Base64 encoded icon (optional)
  String? iconBase64;

  /// Whether this app is selected for per-app proxy
  bool isSelected;

  AppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
    this.iconBase64,
    this.isSelected = false,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final packageName =
        (json['package-name'] ?? json['packageName']) as String? ?? '';
    final name = (json['name'] as String?)?.trim();
    final systemRaw = json['is-system-app'] ?? json['isSystemApp'];
    final isSystemApp = switch (systemRaw) {
      true || 1 => true,
      false || 0 || null => false,
      _ => systemRaw.toString() == 'true',
    };
    return AppInfo(
      packageName: packageName,
      name: (name == null || name.isEmpty) ? packageName : name,
      isSystemApp: isSystemApp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package-name': packageName,
      'name': name,
      'is-system-app': isSystemApp,
    };
  }

  @override
  String toString() => 'AppInfo(packageName: $packageName, name: $name)';
}

