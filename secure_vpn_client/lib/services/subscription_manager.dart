import '../models/subscription_server.dart';
import '../models/transport_stack.dart';
import '../utils/transport_stack_classifier.dart';
import 'transport_stack_store.dart';

class SubscriptionManager {
  SubscriptionManager({TransportStackStore? store})
      : _store = store ?? TransportStackStore();

  final TransportStackStore _store;

  TransportStackStore get store => _store;

  List<LogicalSubscriptionServer> groupServers(
    List<SubscriptionServer> servers,
  ) {
    final groups = <String, List<TransportStackCandidate>>{};
    final names = <String, String>{};
    final primaryIndex = <String, int>{};

    for (final server in servers) {
      final key = TransportStackClassifier.serverKey(server);
      final kind = TransportStackClassifier.classify(server);
      final candidate = TransportStackCandidate(
        kind: kind,
        server: server,
        tag: TransportStackClassifier.tagFor(kind),
      );
      groups.putIfAbsent(key, () => []).add(candidate);
      names.putIfAbsent(key, () => server.name);
      primaryIndex.putIfAbsent(key, () => server.index);
    }

    return groups.entries.map((entry) {
      final stacks = _dedupeStacks(entry.value);
      return LogicalSubscriptionServer(
        key: entry.key,
        displayName: names[entry.key] ?? entry.key,
        stacks: stacks,
        primaryIndex: primaryIndex[entry.key] ?? stacks.first.server.index,
      );
    }).toList()
      ..sort((a, b) => a.primaryIndex.compareTo(b.primaryIndex));
  }

  Future<List<TransportStackCandidate>> orderedProbeList({
    required String profileId,
    required List<SubscriptionServer> servers,
    required int selectedIndex,
  }) async {
    if (servers.isEmpty) {
      return const [];
    }

    final selected = servers.firstWhere(
      (server) => server.index == selectedIndex,
      orElse: () => servers.first,
    );
    final key = TransportStackClassifier.serverKey(selected);
    final group = groupServers(servers).firstWhere(
      (logical) => logical.key == key,
      orElse: () {
        final kind = TransportStackClassifier.classify(selected);
        return LogicalSubscriptionServer(
          key: key,
          displayName: selected.name,
          stacks: [
            TransportStackCandidate(
              kind: kind,
              server: selected,
              tag: TransportStackClassifier.tagFor(kind),
            ),
          ],
          primaryIndex: selected.index,
        );
      },
    );

    return _orderStacks(
      profileId: profileId,
      serverKey: group.key,
      stacks: group.stacks,
    );
  }

  List<SubscriptionServer> listLogicalServers(List<SubscriptionServer> servers) {
    return groupServers(servers)
        .map(
          (logical) => SubscriptionServer(
            index: logical.primaryIndex,
            name: logical.hasMultipleStacks
                ? '${logical.displayName} (${logical.stackTagsLabel})'
                : logical.displayName,
            content: logical.stacks.first.content,
          ),
        )
        .toList();
  }

  Future<List<TransportStackCandidate>> _orderStacks({
    required String profileId,
    required String serverKey,
    required List<TransportStackCandidate> stacks,
  }) async {
    if (stacks.length <= 1) {
      return stacks;
    }

    final stats = <TransportStackKind, TransportStackStats>{};
    for (final stack in stacks) {
      final loaded = await _store.load(
        profileId: profileId,
        serverKey: serverKey,
        kind: stack.kind,
      );
      if (loaded != null) {
        stats[stack.kind] = loaded;
      }
    }

    final ordered = List<TransportStackCandidate>.from(stacks);
    ordered.sort((a, b) {
      final aStats = stats[a.kind];
      final bStats = stats[b.kind];
      if (aStats != null && bStats != null) {
        final bySuccess = bStats.successRate.compareTo(aStats.successRate);
        if (bySuccess != 0) {
          return bySuccess;
        }
        if (aStats.lastLatencyMs >= 0 && bStats.lastLatencyMs >= 0) {
          final byLatency =
              aStats.lastLatencyMs.compareTo(bStats.lastLatencyMs);
          if (byLatency != 0) {
            return byLatency;
          }
        }
      } else if (aStats != null) {
        return -1;
      } else if (bStats != null) {
        return 1;
      }

      final byDefault =
          a.kind.defaultPriority.compareTo(b.kind.defaultPriority);
      if (byDefault != 0) {
        return byDefault;
      }
      return a.server.index.compareTo(b.server.index);
    });

    return ordered;
  }

  List<TransportStackCandidate> _dedupeStacks(
    List<TransportStackCandidate> stacks,
  ) {
    final seen = <TransportStackKind>{};
    final result = <TransportStackCandidate>[];
    for (final stack in stacks) {
      if (seen.add(stack.kind)) {
        result.add(stack);
      }
    }
    return result;
  }
}
