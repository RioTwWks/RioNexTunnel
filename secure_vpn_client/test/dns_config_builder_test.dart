import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/dns_settings.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/dns_config_builder.dart';
void main() {
  test('DoH URL maps to sing-box type https', () {
    final config = _singbox();
    DnsConfigBuilder.apply(config, const DnsSettings(mode: DnsMode.encrypted, upstreams: [DnsUpstream(label: 'CF', kind: DnsUpstreamKind.doh, address: 'https://cloudflare-dns.com/dns-query')], leakProtectionEnabled: true), VpnEngine.singbox, proxyOnly: false);
    final server = ((config['dns'] as Map)['servers'] as List).first as Map;
    expect(server['type'], 'https'); expect(server['detour'], 'proxy');
  });
  test('DoT maps to sing-box type tls', () {
    final config = _singbox();
    DnsConfigBuilder.apply(config, const DnsSettings(mode: DnsMode.encrypted, upstreams: [DnsUpstream(label: 'Quad9', kind: DnsUpstreamKind.dot, address: '9.9.9.9')], leakProtectionEnabled: true), VpnEngine.singbox, proxyOnly: false);
    final server = ((config['dns'] as Map)['servers'] as List).first as Map;
    expect(server['type'], 'tls'); expect(server['server_port'], 853);
  });
  test('leak protection adds hijack-dns', () {
    final config = _singbox();
    DnsConfigBuilder.apply(config, const DnsSettings(), VpnEngine.singbox, proxyOnly: false);
    expect(((config['route'] as Map)['rules'] as List).any((r) => r is Map && r['action'] == 'hijack-dns'), isTrue);
  });
}
Map<String, dynamic> _singbox() => jsonDecode('{"outbounds":[{"type":"vless","tag":"proxy"}],"route":{"final":"proxy","rules":[]}}') as Map<String, dynamic>;
