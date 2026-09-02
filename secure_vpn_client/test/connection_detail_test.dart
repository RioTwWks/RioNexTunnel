import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/connection_detail.dart';
import 'package:v2ray_box/v2ray_box.dart';

void main() {
  group('ConnectionDetail', () {
    test('displayLabel reflects phase', () {
      expect(
        const ConnectionDetail(phase: ConnectionPhase.reconnecting)
            .displayLabel,
        'Reconnecting',
      );
      expect(
        const ConnectionDetail(
          phase: ConnectionPhase.reconnecting,
          reconnectAttempt: 2,
          maxReconnectAttempts: 5,
        ).displayLabel,
        'Reconnecting (2/5)',
      );
      expect(
        const ConnectionDetail(
          phase: ConnectionPhase.error,
          reason: 'timeout',
        ).subtitle,
        'timeout',
      );
    });

    test('fromVpnStatus maps plugin status', () {
      final detail = ConnectionDetail.fromVpnStatus(VpnStatus.starting);
      expect(detail.phase, ConnectionPhase.connecting);
      expect(detail.vpnStatus, VpnStatus.starting);
    });
  });
}
