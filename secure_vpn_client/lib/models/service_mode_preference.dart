import 'package:v2ray_box/v2ray_box.dart';

enum ServiceModePreference {
  auto,
  proxy,
  vpn;

  String get storageName => name;

  static ServiceModePreference fromStorage(String? value) {
    switch (value?.toLowerCase()) {
      case 'proxy':
        return ServiceModePreference.proxy;
      case 'vpn':
        return ServiceModePreference.vpn;
      default:
        return ServiceModePreference.auto;
    }
  }

  VpnMode resolveVpnMode({required bool isDesktop}) {
    switch (this) {
      case ServiceModePreference.auto:
        return isDesktop ? VpnMode.proxy : VpnMode.vpn;
      case ServiceModePreference.proxy:
        return VpnMode.proxy;
      case ServiceModePreference.vpn:
        return VpnMode.vpn;
    }
  }

  bool showsDesktopVpnWarning({required bool isDesktop}) {
    return isDesktop && this == ServiceModePreference.vpn;
  }
}
