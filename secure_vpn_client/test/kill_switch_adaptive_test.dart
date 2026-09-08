import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_vpn_client/models/kill_switch_mode.dart';
import 'package:secure_vpn_client/providers/kill_switch_provider.dart';
import 'package:secure_vpn_client/services/kill_switch_service.dart';
import 'package:v2ray_box/v2ray_box.dart';
import 'package:v2ray_box/v2ray_box_platform_interface.dart';
class _F extends V2rayBoxPlatform {
  @override Future<bool> setKillSwitchMode(String m) async => true;
  @override Future<bool> armKillSwitch({int? socksPort}) async => true;
  @override Future<bool> engageKillSwitch() async => true;
  @override Future<bool> disengageKillSwitch() async => true;
  @override Future<bool> releaseKillSwitch() async => true;
  @override Future<Map<String, dynamic>> getKillSwitchStatus() async => {};
}
void main() {
  setUp(() => V2rayBoxPlatform.instance = _F());
  test('persists adaptive', () async {
    SharedPreferences.setMockInitialValues({});
    final n = KillSwitchModeNotifier(KillSwitchService(V2rayBox()));
    await Future<void>.delayed(Duration.zero);
    await n.setMode(KillSwitchMode.adaptive);
    expect(n.state, KillSwitchMode.adaptive);
  });
}
