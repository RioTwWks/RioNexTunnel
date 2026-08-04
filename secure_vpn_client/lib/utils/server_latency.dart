import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/subscription_server.dart';
import 'link_config_builder.dart';

/// Host:port extracted from a subscription entry for reachability probes.
class ServerEndpoint {
  const ServerEndpoint({required this.host, required this.port});

  final String host;
  final int port;

  @override
  String toString() => '$host:$port';
}

/// Latency result for one [SubscriptionServer].
class ServerLatencyResult {
  const ServerLatencyResult({required this.server, required this.latencyMs});

  final SubscriptionServer server;

  /// Round-trip TCP connect time in ms, or `-1` on failure/timeout.
  final int latencyMs;

  bool get isReachable => latencyMs >= 0;
}

/// TCP connect latency probe used for auto-selecting the best server.
///
/// Measures reachability of the VPN node address (not full tunnel quality).
/// Works on all platforms — Linux desktop has no native `url_test`.
class ServerLatencyProbe {
  static const defaultTimeout = Duration(seconds: 3);
  static const defaultConcurrency = 8;

  /// Extracts host/port from a share link or Xray/sing-box JSON config.
  static ServerEndpoint? endpointFromContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (LinkConfigBuilder.isConfigLink(trimmed)) {
      return _endpointFromLink(trimmed);
    }
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return _endpointFromConfig(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static ServerEndpoint? _endpointFromLink(String link) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vmess://')) {
      try {
        final encoded = link.substring('vmess://'.length);
        final decoded = utf8.decode(base64.decode(_padBase64(encoded)));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final host = json['add']?.toString();
        final port = int.tryParse(json['port']?.toString() ?? '');
        if (host == null || host.isEmpty || port == null || port <= 0) {
          return null;
        }
        return ServerEndpoint(host: host, port: port);
      } catch (_) {
        return null;
      }
    }

    try {
      final uri = Uri.parse(link);
      if (uri.host.isEmpty) {
        return null;
      }
      final port = uri.hasPort
          ? uri.port
          : (lower.startsWith('ss://') ? 8388 : 443);
      if (port <= 0) {
        return null;
      }
      return ServerEndpoint(host: uri.host, port: port);
    } catch (_) {
      return null;
    }
  }

  static ServerEndpoint? _endpointFromConfig(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return null;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final outbound = Map<String, dynamic>.from(raw);
      final fromSingbox = _endpointFromSingboxOutbound(outbound);
      if (fromSingbox != null) {
        return fromSingbox;
      }
      final fromXray = _endpointFromXrayOutbound(outbound);
      if (fromXray != null) {
        return fromXray;
      }
    }
    return null;
  }

  static ServerEndpoint? _endpointFromSingboxOutbound(
    Map<String, dynamic> outbound,
  ) {
    final type = outbound['type']?.toString();
    if (type != 'vless' &&
        type != 'vmess' &&
        type != 'trojan' &&
        type != 'shadowsocks') {
      return null;
    }
    final host = outbound['server']?.toString();
    final port =
        (outbound['server_port'] as num?)?.toInt() ??
        int.tryParse(outbound['server_port']?.toString() ?? '');
    if (host == null || host.isEmpty || port == null || port <= 0) {
      return null;
    }
    return ServerEndpoint(host: host, port: port);
  }

  static ServerEndpoint? _endpointFromXrayOutbound(
    Map<String, dynamic> outbound,
  ) {
    final protocol = outbound['protocol']?.toString();
    if (protocol != 'vless' &&
        protocol != 'vmess' &&
        protocol != 'trojan' &&
        protocol != 'shadowsocks') {
      return null;
    }
    final settings = outbound['settings'];
    if (settings is! Map) {
      return null;
    }
    final settingsMap = Map<String, dynamic>.from(settings);

    final vnext = settingsMap['vnext'];
    if (vnext is List && vnext.isNotEmpty && vnext.first is Map) {
      final node = Map<String, dynamic>.from(vnext.first as Map);
      final host = node['address']?.toString();
      final port =
          (node['port'] as num?)?.toInt() ??
          int.tryParse(node['port']?.toString() ?? '');
      if (host != null && host.isNotEmpty && port != null && port > 0) {
        return ServerEndpoint(host: host, port: port);
      }
    }

    final servers = settingsMap['servers'];
    if (servers is List && servers.isNotEmpty && servers.first is Map) {
      final node = Map<String, dynamic>.from(servers.first as Map);
      final host = node['address']?.toString();
      final port =
          (node['port'] as num?)?.toInt() ??
          int.tryParse(node['port']?.toString() ?? '');
      if (host != null && host.isNotEmpty && port != null && port > 0) {
        return ServerEndpoint(host: host, port: port);
      }
    }
    return null;
  }

  /// TCP connect RTT to [endpoint], or `-1` on failure.
  static Future<int> measureTcpLatency(
    ServerEndpoint endpoint, {
    Duration timeout = defaultTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: timeout,
      );
      final ms = stopwatch.elapsedMilliseconds;
      try {
        await socket.close();
      } catch (_) {
        // Ignore close errors after a successful connect.
      }
      return ms;
    } on Object {
      return -1;
    }
  }

  static Future<ServerLatencyResult> probeServer(
    SubscriptionServer server, {
    Duration timeout = defaultTimeout,
  }) async {
    final endpoint = endpointFromContent(server.content);
    if (endpoint == null) {
      return ServerLatencyResult(server: server, latencyMs: -1);
    }
    final latency = await measureTcpLatency(endpoint, timeout: timeout);
    return ServerLatencyResult(server: server, latencyMs: latency);
  }

  /// Probes servers with limited concurrency. Invokes [onResult] as each finishes.
  static Future<List<ServerLatencyResult>> probeAll(
    List<SubscriptionServer> servers, {
    Duration timeout = defaultTimeout,
    int concurrency = defaultConcurrency,
    void Function(ServerLatencyResult result)? onResult,
  }) async {
    if (servers.isEmpty) {
      return const [];
    }
    final results = List<ServerLatencyResult?>.filled(servers.length, null);
    var nextIndex = 0;
    final workers = concurrency.clamp(1, servers.length);

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= servers.length) {
          return;
        }
        final result = await probeServer(servers[index], timeout: timeout);
        results[index] = result;
        onResult?.call(result);
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return results.map((r) => r!).toList();
  }

  /// Lowest positive latency; ties broken by smaller server index.
  /// Returns `null` if every probe failed.
  static ServerLatencyResult? selectBest(List<ServerLatencyResult> results) {
    ServerLatencyResult? best;
    for (final result in results) {
      if (!result.isReachable) {
        continue;
      }
      if (best == null ||
          result.latencyMs < best.latencyMs ||
          (result.latencyMs == best.latencyMs &&
              result.server.index < best.server.index)) {
        best = result;
      }
    }
    return best;
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }
}

/// Thrown when auto-select cannot find a reachable server.
class ServerLatencyException implements Exception {
  ServerLatencyException(this.message);

  final String message;

  @override
  String toString() => 'ServerLatencyException: $message';
}
