import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/subscription_server.dart';
import '../models/vpn_engine.dart';
import 'ping_config_builder.dart';
import 'server_latency.dart';

/// Probes subscription servers for latency using the best method per platform.
///
/// Android: core HTTP delay through a temporary outbound (Hiddify-style URL test).
/// Linux desktop: temporary core + HTTP through local inbound (tunnel-quality).
/// Other platforms: TCP connect RTT to host:port (reachability only).
class SubscriptionLatencyProbe {
  SubscriptionLatencyProbe(this._box, {required this.engine});

  final V2rayBox _box;
  final VpnEngine engine;

  static bool get supportsAndroidCorePing {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  static bool get supportsDesktopTunnelPing {
    if (kIsWeb) {
      return false;
    }
    return Platform.isLinux;
  }

  static bool get supportsCorePing =>
      supportsAndroidCorePing || supportsDesktopTunnelPing;

  /// Default probe timeout; core ping uses ms, TCP probe uses [Duration].
  static const defaultTimeoutMs = 5000;

  Future<ServerLatencyResult> probeServer(
    SubscriptionServer server, {
    int timeoutMs = defaultTimeoutMs,
  }) async {
    if (supportsCorePing) {
      final coreLatency = await _probeWithCore(server, timeoutMs: timeoutMs);
      if (coreLatency >= 0) {
        return ServerLatencyResult(server: server, latencyMs: coreLatency);
      }
    }
    return ServerLatencyProbe.probeServer(
      server,
      timeout: Duration(milliseconds: timeoutMs),
    );
  }

  Future<List<ServerLatencyResult>> probeAll(
    List<SubscriptionServer> servers, {
    int timeoutMs = defaultTimeoutMs,
    int concurrency = ServerLatencyProbe.defaultConcurrency,
    void Function(ServerLatencyResult result)? onResult,
  }) async {
    if (servers.isEmpty) {
      return const [];
    }

    if (supportsAndroidCorePing && servers.length > 1) {
      return _probeAllWithAndroidCore(
        servers,
        timeoutMs: timeoutMs,
        onResult: onResult,
      );
    }

    if (supportsCorePing) {
      return _probeAllParallel(
        servers,
        timeoutMs: timeoutMs,
        concurrency: concurrency,
        onResult: onResult,
      );
    }

    return ServerLatencyProbe.probeAll(
      servers,
      timeout: Duration(milliseconds: timeoutMs),
      concurrency: concurrency,
      onResult: onResult,
    );
  }

  static ServerLatencyResult? selectBest(List<ServerLatencyResult> results) {
    return ServerLatencyProbe.selectBest(results);
  }

  Future<int> _probeWithCore(
    SubscriptionServer server, {
    required int timeoutMs,
  }) async {
    if (supportsDesktopTunnelPing) {
      return _probeDesktopTunnel(server.content, timeoutMs: timeoutMs);
    }
    return _probeAndroidCore(server.content, timeoutMs: timeoutMs);
  }

  Future<int> _probeAndroidCore(
    String link, {
    required int timeoutMs,
  }) async {
    try {
      return await _box.ping(link, timeout: timeoutMs);
    } on PlatformException catch (error) {
      if (error.code == 'NOT_SUPPORTED') {
        return -1;
      }
      return -1;
    } on Object {
      return -1;
    }
  }

  Future<int> _probeDesktopTunnel(
    String content, {
    required int timeoutMs,
  }) async {
    try {
      final measure = PingConfigBuilder.build(content, engine);
      return await _box.pingConfig(
        measure.configJson,
        engine: measure.engine.coreName,
        socksPort: measure.socksPort,
        timeout: timeoutMs,
      );
    } on ConfigParserException {
      return -1;
    } on PlatformException catch (error) {
      if (error.code == 'NOT_SUPPORTED') {
        return -1;
      }
      return -1;
    } on Object {
      return -1;
    }
  }

  Future<List<ServerLatencyResult>> _probeAllWithAndroidCore(
    List<SubscriptionServer> servers, {
    required int timeoutMs,
    void Function(ServerLatencyResult result)? onResult,
  }) async {
    final contentToServer = <String, SubscriptionServer>{
      for (final server in servers) server.content: server,
    };
    final links = contentToServer.keys.toList();
    final resultsByContent = <String, int>{};
    StreamSubscription<Map<String, dynamic>>? subscription;

    try {
      subscription = _box.watchPingResults().listen((event) {
        final link = event['link']?.toString();
        final latency = (event['latency'] as num?)?.toInt();
        if (link == null || latency == null) {
          return;
        }
        resultsByContent[link] = latency;
        final server = contentToServer[link];
        if (server != null) {
          onResult?.call(
            ServerLatencyResult(server: server, latencyMs: latency),
          );
        }
      });

      final batch = await _box.pingAll(links, timeout: timeoutMs);
      resultsByContent.addAll(batch);
    } on PlatformException catch (error) {
      if (error.code != 'NOT_SUPPORTED') {
        rethrow;
      }
      return ServerLatencyProbe.probeAll(
        servers,
        timeout: Duration(milliseconds: timeoutMs),
        onResult: onResult,
      );
    } finally {
      await subscription?.cancel();
    }

    return servers
        .map(
          (server) => ServerLatencyResult(
            server: server,
            latencyMs: resultsByContent[server.content] ?? -1,
          ),
        )
        .toList();
  }

  Future<List<ServerLatencyResult>> _probeAllParallel(
    List<SubscriptionServer> servers, {
    required int timeoutMs,
    required int concurrency,
    void Function(ServerLatencyResult result)? onResult,
  }) async {
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
        final result = await probeServer(servers[index], timeoutMs: timeoutMs);
        results[index] = result;
        onResult?.call(result);
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return results.map((r) => r!).toList();
  }
}

/// Color bucket for latency display (Hiddify-style traffic-light).
enum LatencyQuality {
  unknown,
  timeout,
  excellent,
  good,
  fair,
  poor;

  static LatencyQuality fromMs(int? latencyMs) {
    if (latencyMs == null) {
      return unknown;
    }
    if (latencyMs < 0) {
      return timeout;
    }
    if (latencyMs < 100) {
      return excellent;
    }
    if (latencyMs < 200) {
      return good;
    }
    if (latencyMs < 400) {
      return fair;
    }
    return poor;
  }
}
