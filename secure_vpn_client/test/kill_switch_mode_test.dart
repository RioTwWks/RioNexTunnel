import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/kill_switch_mode.dart';

void main() {
  test('fromStorage defaults to off', () {
    expect(KillSwitchMode.fromStorage(null), KillSwitchMode.off);
    expect(KillSwitchMode.fromStorage('bad'), KillSwitchMode.off);
  });

  test('strict is enabled', () {
    expect(KillSwitchMode.strict.isStrict, isTrue);
    expect(KillSwitchMode.strict.isEnabled, isTrue);
  });
}
