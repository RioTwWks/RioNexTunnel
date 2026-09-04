import '../models/dns_settings.dart';
import '../models/vpn_engine.dart';

class DnsConfigBuilder {
  DnsConfigBuilder._();
  static const _proxyTag = 'proxy';
  static const _strategy = 'prefer_ipv4';

  static void apply(Map<String, dynamic> config, DnsSettings settings, VpnEngine engine, {required bool proxyOnly}) {
    if (proxyOnly) return;
    engine == VpnEngine.singbox ? _applySingbox(config, settings) : _applyXray(config, settings);
  }

  static void ensureSingboxRemoteDns(Map<String, dynamic> config, {DnsSettings? settings}) {
    if (settings == null || (settings.mode == DnsMode.defaultMode && !settings.leakProtectionEnabled)) { _defaults(config); return; }
    _applySingbox(config, settings);
  }

  static Map<String, dynamic> defaultSingboxDnsBlock() => {
    'servers': _udpServers(DnsSettings.defaultUdpUpstreams, throughProxy: false),
    'final': 'dns-direct', 'strategy': _strategy,
  };

  static void _defaults(Map<String, dynamic> config) {
    final servers = <Map<String, dynamic>>[];
    final dns = config['dns'];
    if (dns is Map) {
      for (final raw in dns['servers'] as List<dynamic>? ?? const []) {
        if (raw is! Map) continue;
        final server = Map<String, dynamic>.from(raw);
        if (server['type'] == 'local') continue;
        if (server['detour'] == 'direct') server.remove('detour');
        servers.add(server);
      }
    }
    if (servers.isEmpty) servers.addAll(_udpServers(DnsSettings.defaultUdpUpstreams, throughProxy: false));
    _finalizeSingbox(config, servers, leakProtection: false);
  }

  static void _applySingbox(Map<String, dynamic> config, DnsSettings settings) {
    final throughProxy = settings.leakProtectionEnabled || settings.mode == DnsMode.encrypted;
    final servers = <Map<String, dynamic>>[];
    final upstreams = settings.effectiveUpstreams();
    for (var i = 0; i < upstreams.length; i++) {
      servers.add(_fromUpstream(upstreams[i], tag: i == 0 ? 'dns-direct' : 'dns-${i + 1}', throughProxy: throughProxy));
    }
    if (servers.isEmpty) servers.addAll(_udpServers(DnsSettings.defaultUdpUpstreams, throughProxy: throughProxy));
    _finalizeSingbox(config, servers, leakProtection: settings.leakProtectionEnabled);
  }

  static void _finalizeSingbox(Map<String, dynamic> config, List<Map<String, dynamic>> servers, {required bool leakProtection}) {
    final tag = servers.first['tag']?.toString() ?? 'dns-direct';
    servers.first['tag'] ??= tag;
    config['dns'] = {'servers': servers, 'final': tag, 'strategy': _strategy, 'independent_cache': true};
    final routeMap = config['route'] is Map ? Map<String, dynamic>.from(config['route'] as Map) : <String, dynamic>{'final': _proxyTag};
    routeMap['default_domain_resolver'] = {'server': tag, 'strategy': _strategy};
    routeMap.putIfAbsent('final', () => _proxyTag);
    if (leakProtection) {
      final rules = List<dynamic>.from(routeMap['rules'] as List<dynamic>? ?? const []);
      if (!rules.any((r) => r is Map && r['action'] == 'hijack-dns')) rules.insert(0, {'protocol': 'dns', 'action': 'hijack-dns'});
      routeMap['rules'] = rules;
    }
    config['route'] = routeMap;
  }

  static List<Map<String, dynamic>> _udpServers(List<DnsUpstream> upstreams, {required bool throughProxy}) =>
    [for (var i = 0; i < upstreams.length; i++) _fromUpstream(upstreams[i], tag: i == 0 ? 'dns-direct' : 'dns-backup', throughProxy: throughProxy)];

  static Map<String, dynamic> _fromUpstream(DnsUpstream upstream, {required String tag, required bool throughProxy}) {
    final Map<String, dynamic> server;
    switch (upstream.kind) {
      case DnsUpstreamKind.udp: server = {'type': 'udp', 'tag': tag, 'server': upstream.address};
      case DnsUpstreamKind.doh:
        final uri = Uri.parse(upstream.address);
        server = {'type': 'https', 'tag': tag, 'server': uri.host, 'server_port': uri.hasPort ? uri.port : 443, 'path': uri.path.isEmpty ? '/dns-query' : uri.path};
      case DnsUpstreamKind.dot: server = {'type': 'tls', 'tag': tag, 'server': upstream.address, 'server_port': 853};
    }
    if (throughProxy) server['detour'] = _proxyTag;
    return server;
  }

  static void _applyXray(Map<String, dynamic> config, DnsSettings settings) {
    final servers = settings.effectiveUpstreams().map((u) => switch (u.kind) {
      DnsUpstreamKind.udp => u.address, DnsUpstreamKind.doh => u.address, DnsUpstreamKind.dot => 'tls://${u.address}',
    }).toList();
    config['dns'] = {'servers': servers, 'queryStrategy': 'UseIPv4'};
    if (!settings.leakProtectionEnabled) return;
    final outbounds = List<dynamic>.from(config['outbounds'] as List<dynamic>? ?? const []);
    if (!outbounds.any((o) => o is Map && o['tag'] == 'dns-out')) {
      outbounds.add({'tag': 'dns-out', 'protocol': 'dns', 'settings': {'network': 'tcp,udp', 'address': servers.first}});
      config['outbounds'] = outbounds;
    }
    final routing = config['routing'] is Map ? Map<String, dynamic>.from(config['routing'] as Map) : <String, dynamic>{'domainStrategy': 'AsIs'};
    final rules = List<dynamic>.from(routing['rules'] as List<dynamic>? ?? const []);
    if (!rules.any((r) => r is Map && r['port'] == '53')) rules.insert(0, {'type': 'field', 'network': 'tcp,udp', 'port': '53', 'outboundTag': 'dns-out'});
    routing['rules'] = rules; config['routing'] = routing;
  }
}
