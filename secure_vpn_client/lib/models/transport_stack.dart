import '../utils/transport_stack_classifier.dart';
import 'subscription_server.dart';

enum TransportStackKind {
  xhttpReality,
  tlsMux,
  tcpRealityVision,
  amneziaWg,
  other,
}

extension TransportStackKindLabels on TransportStackKind {
  String get shortLabel => switch (this) {
        TransportStackKind.xhttpReality => 'XHTTP',
        TransportStackKind.tlsMux => 'TLS+mux',
        TransportStackKind.tcpRealityVision => 'Vision',
        TransportStackKind.amneziaWg => 'AmneziaWG',
        TransportStackKind.other => 'Other',
      };

  int get defaultPriority => switch (this) {
        TransportStackKind.xhttpReality => 0,
        TransportStackKind.tlsMux => 1,
        TransportStackKind.tcpRealityVision => 2,
        TransportStackKind.amneziaWg => 3,
        TransportStackKind.other => 99,
      };
}

class TransportStackCandidate {
  const TransportStackCandidate({
    required this.kind,
    required this.server,
    required this.tag,
  });

  final TransportStackKind kind;
  final SubscriptionServer server;
  final String tag;

  String get content => server.content;

  String get stackSummary => TransportStackClassifier.stackSummary(kind, content);
}

class LogicalSubscriptionServer {
  const LogicalSubscriptionServer({
    required this.key,
    required this.displayName,
    required this.stacks,
    required this.primaryIndex,
  });

  final String key;
  final String displayName;
  final List<TransportStackCandidate> stacks;
  final int primaryIndex;

  bool get hasMultipleStacks => stacks.length > 1;

  String get stackTagsLabel => stacks.map((stack) => stack.tag).join(' · ');
}

class TransportStackStats {
  const TransportStackStats({
    this.lastLatencyMs = -1,
    this.successCount = 0,
    this.attemptCount = 0,
    this.lastSuccessAtMs,
  });

  final int lastLatencyMs;
  final int successCount;
  final int attemptCount;
  final int? lastSuccessAtMs;

  double get successRate =>
      attemptCount == 0 ? 0 : successCount / attemptCount;

  Map<String, dynamic> toJson() => {
        'lastLatencyMs': lastLatencyMs,
        'successCount': successCount,
        'attemptCount': attemptCount,
        if (lastSuccessAtMs != null) 'lastSuccessAtMs': lastSuccessAtMs,
      };

  factory TransportStackStats.fromJson(Map<String, dynamic> json) {
    return TransportStackStats(
      lastLatencyMs: (json['lastLatencyMs'] as num?)?.toInt() ?? -1,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastSuccessAtMs: (json['lastSuccessAtMs'] as num?)?.toInt(),
    );
  }

  TransportStackStats recordAttempt({required bool success, int? latencyMs}) {
    return TransportStackStats(
      lastLatencyMs: latencyMs ?? lastLatencyMs,
      successCount: successCount + (success ? 1 : 0),
      attemptCount: attemptCount + 1,
      lastSuccessAtMs: success
          ? DateTime.now().millisecondsSinceEpoch
          : lastSuccessAtMs,
    );
  }
}
