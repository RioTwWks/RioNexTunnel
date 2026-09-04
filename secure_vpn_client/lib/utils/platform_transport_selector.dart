import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../models/transport_preset.dart';
import 'link_config_builder.dart';
import 'server_latency.dart';
import 'transport_presets.dart';

enum CensorshipTransportStack {
  xhttpReality,
  tcpRealityVision,
  tlsMux,
  other,
}

class PlatformTransportSelector {
  PlatformTransportSelector._();

  static bool get isIos => !kIsWeb && Platform.isIOS;

  static CensorshipTransportStack classifyStack(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return CensorshipTransportStack.other;
    }
    if (_hasTcpRealityVision(trimmed)) {
      return CensorshipTransportStack.tcpRealityVision;
    }
    final detected = TransportPresets.detectFromContent(trimmed);
    if (detected.preset == TransportPresetId.xhttpReality ||
        detected.network == 'xhttp') {
      return CensorshipTransportStack.xhttpReality;
    }
    if (detected.hasMux &&
        (detected.security == 'tls' ||
            detected.preset == TransportPresetId.plainTls)) {
      return CensorshipTransportStack.tlsMux;
    }
    return CensorshipTransportStack.other;
  }

  static int stackPriority(CensorshipTransportStack stack, {bool? ios}) {
    final onIos = ios ?? isIos;
    if (onIos) {
      return switch (stack) {
        CensorshipTransportStack.tcpRealityVision => 0,
        CensorshipTransportStack.other => 20,
        CensorshipTransportStack.tlsMux => 30,
        CensorshipTransportStack.xhttpReality => 100,
      };
    }
    return switch (stack) {
      CensorshipTransportStack.xhttpReality => 0,
      CensorshipTransportStack.tcpRealityVision => 10,
      CensorshipTransportStack.tlsMux => 20,
      CensorshipTransportStack.other => 50,
    };
  }

  static ServerLatencyResult? selectBest(
    List<ServerLatencyResult> results, {
    bool? ios,
  }) {
    final reachable = results.where((result) => result.isReachable).toList();
    if (reachable.isEmpty) {
      return null;
    }
    final onIos = ios ?? isIos;
    reachable.sort((a, b) {
      final priorityA = stackPriority(
        classifyStack(a.server.content),
        ios: onIos,
      );
      final priorityB = stackPriority(
        classifyStack(b.server.content),
        ios: onIos,
      );
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      if (a.latencyMs != b.latencyMs) {
        return a.latencyMs.compareTo(b.latencyMs);
      }
      return a.server.index.compareTo(b.server.index);
    });
    return reachable.first;
  }

  static bool _hasTcpRealityVision(String content) {
    if (LinkConfigBuilder.isConfigLink(content)) {
      return _visionFromLink(content);
    }
    if (content.startsWith('{')) {
      return _visionFromJson(content);
    }
    return false;
  }

  static bool _visionFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;
      final security = (params['security'] ?? '').toLowerCase();
      final type = (params['type'] ?? 'tcp').toLowerCase();
      final flow = (params['flow'] ?? '').toLowerCase();
      return security == 'reality' &&
          (type == 'tcp' || type.isEmpty) &&
          _flowIsVision(flow);
    } catch (_) {
      return false;
    }
  }

  static bool _visionFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        return false;
      }
      final outbounds = decoded['outbounds'];
      if (outbounds is! List) {
        return false;
      }
      for (final raw in outbounds) {
        if (raw is! Map) {
          continue;
        }
        final outbound = Map<String, dynamic>.from(raw);
        if (!_isProxyOutbound(outbound)) {
          continue;
        }
        final stream = outbound['streamSettings'];
        if (stream is! Map) {
          continue;
        }
        final network = stream['network']?.toString().toLowerCase() ?? 'tcp';
        final security = stream['security']?.toString().toLowerCase() ?? '';
        if (security != 'reality' || (network != 'tcp' && network.isNotEmpty)) {
          continue;
        }
        if (_outboundHasVisionFlow(outbound)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static bool _isProxyOutbound(Map<String, dynamic> outbound) {
    final protocol = outbound['protocol']?.toString();
    final type = outbound['type']?.toString();
    return protocol == 'vless' ||
        protocol == 'vmess' ||
        type == 'vless' ||
        type == 'vmess';
  }

  static bool _outboundHasVisionFlow(Map<String, dynamic> outbound) {
    final settings = outbound['settings'];
    if (settings is! Map) {
      return false;
    }
    final settingsMap = Map<String, dynamic>.from(settings);
    final vnext = settingsMap['vnext'];
    if (vnext is List) {
      for (final raw in vnext) {
        if (raw is! Map) {
          continue;
        }
        final users = raw['users'];
        if (users is! List) {
          continue;
        }
        for (final userRaw in users) {
          if (userRaw is! Map) {
            continue;
          }
          final flow = userRaw['flow']?.toString().toLowerCase() ?? '';
          if (_flowIsVision(flow)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _flowIsVision(String flow) => flow.contains('vision');

  static String? iosSelectionNote(
    List<ServerLatencyResult> results,
    ServerLatencyResult selected, {
    bool? ios,
  }) {
    final onIos = ios ?? isIos;
    if (!onIos) {
      return null;
    }
    final selectedStack = classifyStack(selected.server.content);
    if (selectedStack != CensorshipTransportStack.tcpRealityVision) {
      return null;
    }
    final hadXhttp = results.any(
      (result) =>
          result.isReachable &&
          classifyStack(result.server.content) ==
              CensorshipTransportStack.xhttpReality,
    );
    if (!hadXhttp) {
      return null;
    }
    return 'iOS: selected TCP+REALITY+Vision over XHTTP+REALITY '
        '(platform transport policy).';
  }
}
