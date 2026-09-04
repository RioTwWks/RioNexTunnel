import 'profile.dart';

class MultihopChainException implements Exception {
  MultihopChainException(this.message);
  final String message;
  @override
  String toString() => 'MultihopChainException: $message';
}

class MultihopChain {
  const MultihopChain({required this.serverIndices});
  final List<int> serverIndices;

  static List<int> serverIndicesFromProfile(Profile profile) {
    if (!profile.multihopEnabled) return [profile.selectedServerIndex];
    return [profile.selectedServerIndex, ...profile.hopServerIndices];
  }

  factory MultihopChain.fromProfile(Profile profile) =>
      MultihopChain(serverIndices: serverIndicesFromProfile(profile));

  static void validateProfile(Profile profile, {required int serverCount}) {
    if (!profile.multihopEnabled) return;
    if (profile.type != ProfileType.subscription) {
      throw MultihopChainException('Multihop is only available for subscription profiles');
    }
    if (serverCount < 2) {
      throw MultihopChainException('Multihop requires a subscription with at least 2 servers');
    }
    final indices = serverIndicesFromProfile(profile);
    if (indices.length < 2) {
      throw MultihopChainException('Select at least one additional hop server for multihop');
    }
    final seen = <int>{};
    for (final index in indices) {
      if (index < 0 || index >= serverCount) {
        throw MultihopChainException('Hop server index $index is out of range (0..${serverCount - 1})');
      }
      if (!seen.add(index)) {
        throw MultihopChainException('Duplicate hop server index $index in multihop chain');
      }
    }
  }

  static void validateHopOutbound(Map<String, dynamic> outbound, {required bool isExit, required int hopPosition}) {
    final protocol = _protocolOf(outbound);
    if (protocol == null) throw MultihopChainException('Hop ${hopPosition + 1} has no recognizable proxy outbound');
    if (_utilityProtocols.contains(protocol)) throw MultihopChainException('Cannot chain through $protocol outbound at hop ${hopPosition + 1}');
    if (!isExit && _singboxOnlyProtocols.contains(protocol)) {
      throw MultihopChainException('Protocol $protocol cannot be used as an intermediate hop (hop ${hopPosition + 1})');
    }
    if (!_chainableProtocols.contains(protocol)) {
      throw MultihopChainException('Protocol $protocol is not supported for multihop (hop ${hopPosition + 1})');
    }
  }

  static String? _protocolOf(Map<String, dynamic> outbound) {
    final protocol = outbound['protocol']?.toString();
    if (protocol != null && protocol.isNotEmpty) return protocol.toLowerCase();
    final type = outbound['type']?.toString();
    if (type != null && type.isNotEmpty) return type.toLowerCase();
    return null;
  }

  static const _utilityProtocols = {'direct', 'freedom', 'block', 'blackhole', 'dns'};
  static const _chainableProtocols = {
    'vless', 'vmess', 'trojan', 'shadowsocks', 'ss', 'socks', 'http',
    'hysteria', 'hysteria2', 'hy2', 'tuic', 'wireguard', 'wg', 'ssh',
  };
  static const _singboxOnlyProtocols = {'hysteria', 'hysteria2', 'hy2', 'tuic', 'wireguard', 'wg', 'ssh'};
}
