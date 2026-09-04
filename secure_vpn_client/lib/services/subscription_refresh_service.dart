import '../models/pinning_config.dart';
import '../models/profile.dart';
import '../models/subscription_refresh_interval.dart';
import '../models/vpn_engine.dart';
import '../utils/config_parser.dart';
class SubscriptionRefreshResult {
  const SubscriptionRefreshResult({required this.profileId, required this.success, this.errorMessage, this.serverCount});
  final String profileId; final bool success; final String? errorMessage; final int? serverCount;
}
class SubscriptionRefreshService {
  SubscriptionRefreshService({required this.engine, this.pinning = PinningConfig.disabled});
  final VpnEngine engine; final PinningConfig pinning;
  bool isDue(Profile profile, {DateTime? now}) {
    if (profile.type != ProfileType.subscription) return false;
    final interval = profile.subscriptionRefreshInterval.duration;
    if (interval == null) return false;
    final last = profile.lastSubscriptionFetchAt;
    if (last == null) return true;
    return (now ?? DateTime.now()).difference(last) >= interval;
  }
  List<Profile> dueProfiles(List<Profile> profiles, {DateTime? now}) => profiles.where((p) => isDue(p, now: now)).toList(growable: false);
  Future<SubscriptionRefreshResult> refreshProfile(Profile profile) async {
    if (profile.type != ProfileType.subscription) return SubscriptionRefreshResult(profileId: profile.id, success: false, errorMessage: 'Not a subscription profile');
    try {
      final servers = await ConfigParser.listServersFromUrl(profile.configLink, engine: engine, pinning: pinning);
      if (servers.isEmpty) return SubscriptionRefreshResult(profileId: profile.id, success: false, errorMessage: 'Subscription returned no servers');
      return SubscriptionRefreshResult(profileId: profile.id, success: true, serverCount: servers.length);
    } catch (e) {
      return SubscriptionRefreshResult(profileId: profile.id, success: false, errorMessage: e.toString());
    }
  }
}
List<Profile> sortProfiles(List<Profile> profiles) {
  final sorted = [...profiles];
  sorted.sort((a, b) {
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    final au = a.lastUsedAt, bu = b.lastUsedAt;
    if (au != null && bu != null) { final c = bu.compareTo(au); if (c != 0) return c; }
    else if (au != null) return -1; else if (bu != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}
