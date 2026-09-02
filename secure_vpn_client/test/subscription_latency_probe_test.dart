import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/utils/subscription_latency_probe.dart';

void main() {
  group('LatencyQuality', () {
    test('maps latency buckets', () {
      expect(LatencyQuality.fromMs(null), LatencyQuality.unknown);
      expect(LatencyQuality.fromMs(-1), LatencyQuality.timeout);
      expect(LatencyQuality.fromMs(50), LatencyQuality.excellent);
      expect(LatencyQuality.fromMs(150), LatencyQuality.good);
      expect(LatencyQuality.fromMs(300), LatencyQuality.fair);
      expect(LatencyQuality.fromMs(500), LatencyQuality.poor);
    });
  });
}
