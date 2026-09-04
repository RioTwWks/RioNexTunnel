import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/dns_settings.dart';
void main() {
  test('parses DoH and DoT', () {
    expect(DnsUpstream.tryParse(label: 'doh', raw: 'https://dns.google/dns-query')?.kind, DnsUpstreamKind.doh);
    expect(DnsUpstream.tryParse(label: 'dot', raw: 'tls://9.9.9.9')?.kind, DnsUpstreamKind.dot);
  });
  test('encrypted presets used by default', () {
    expect(const DnsSettings(mode: DnsMode.encrypted).effectiveUpstreams(), DnsSettings.encryptedPresets);
  });
}
