import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/service_mode_preference.dart';
import 'package:v2ray_box/v2ray_box.dart';
void main(){test('auto',(){expect(ServiceModePreference.auto.resolveVpnMode(isDesktop:true),VpnMode.proxy);});}
