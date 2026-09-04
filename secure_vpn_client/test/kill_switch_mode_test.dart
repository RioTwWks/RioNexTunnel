import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/kill_switch_mode.dart';
void main() {
  test('adaptive blocks on tunnel drop', () {
    expect(KillSwitchMode.adaptive.isAdaptive, isTrue);
    expect(KillSwitchMode.adaptive.blocksOnTunnelDrop, isTrue);
  });
}
