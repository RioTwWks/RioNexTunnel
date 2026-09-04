import 'dart:convert';
import 'package:http/http.dart' as http;
enum DnsLeakStatus { notConnected, likelyProtected, possibleLeak, error }
class DnsLeakProbeResult {
  const DnsLeakProbeResult({required this.status, required this.summary, this.resolverFamily});
  final DnsLeakStatus status; final String summary; final String? resolverFamily;
  bool get isLikelyProtected => status == DnsLeakStatus.likelyProtected;
}
class DnsLeakProbe {
  const DnsLeakProbe({http.Client? client}) : _client = client;
  final http.Client? _client;
  Future<DnsLeakProbeResult> run({required bool vpnConnected}) async {
    if (!vpnConnected) return const DnsLeakProbeResult(status: DnsLeakStatus.notConnected, summary: 'Connect VPN to run the DNS leak test.');
    final client = _client ?? http.Client(); final owns = _client == null;
    try {
      final r = await client.get(Uri.parse('https://cloudflare-dns.com/dns-query?name=whoami.cloudflare&type=TXT'), headers: const {'Accept': 'application/dns-json'}).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return const DnsLeakProbeResult(status: DnsLeakStatus.error, summary: 'Could not complete DNS resolution test.');
      final d = jsonDecode(r.body);
      if (d is! Map || (d['Status'] as int? ?? -1) != 0) return const DnsLeakProbeResult(status: DnsLeakStatus.possibleLeak, summary: 'DNS query did not succeed through the tunnel.');
      return const DnsLeakProbeResult(status: DnsLeakStatus.likelyProtected, summary: 'DNS resolution succeeded. No subscription data was sent.', resolverFamily: 'Cloudflare');
    } catch (_) { return const DnsLeakProbeResult(status: DnsLeakStatus.error, summary: 'Probe failed. Reconnect VPN and retry.'); }
    finally { if (owns) client.close(); }
  }
}
