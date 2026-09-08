import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/kill_switch_mode.dart';
import 'package:secure_vpn_client/services/kill_switch_service.dart';
import 'package:v2ray_box/v2ray_box.dart';
import 'package:v2ray_box/v2ray_box_platform_interface.dart';

class _FakePlatform extends V2rayBoxPlatform {
  String mode = 'off';
  int armCalls = 0, engageCalls = 0, releaseCalls = 0;
  bool coreRunning = true;
  @override Future<bool> setKillSwitchMode(String mode) async { this.mode = mode; return true; }
  @override Future<bool> armKillSwitch({int? socksPort}) async { armCalls++; return mode == 'strict' || mode == 'adaptive'; }
  @override Future<bool> engageKillSwitch() async { engageCalls++; return true; }
  @override Future<bool> disengageKillSwitch() async => true;
  @override Future<bool> releaseKillSwitch() async { releaseCalls++; return true; }
  @override Future<Map<String, dynamic>> getKillSwitchStatus() async => {};
  @override Future<bool> isCoreRunning() async => coreRunning;
}

void main() {
  late _FakePlatform fake;
  setUp(() { fake = _FakePlatform(); V2rayBoxPlatform.instance = fake; });

  test('strict arms on session start', () async {
    final s = KillSwitchService(V2rayBox());
    await s.loadMode(KillSwitchMode.strict);
    await s.onSessionStart(socksPort: 1080);
    expect(fake.armCalls, 1);
  });

  test('adaptive loadMode sets plugin mode', () async {
    final s = KillSwitchService(V2rayBox());
    await s.loadMode(KillSwitchMode.adaptive);
    expect(fake.mode, 'adaptive');
  });

  test('tunnel down engages once', () async {
    final s = KillSwitchService(V2rayBox());
    await s.loadMode(KillSwitchMode.strict);
    await s.onTunnelDown();
    await s.onTunnelDown();
    expect(fake.engageCalls, 1);
  });
}
