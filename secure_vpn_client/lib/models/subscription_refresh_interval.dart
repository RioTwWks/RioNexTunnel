import 'profile.dart';
enum SubscriptionRefreshInterval { off, hours6, hours12, hours24 }
extension SubscriptionRefreshIntervalX on SubscriptionRefreshInterval {
  static const defaultForSubscription = SubscriptionRefreshInterval.hours6;
  Duration? get duration => switch (this) {
    SubscriptionRefreshInterval.off => null,
    SubscriptionRefreshInterval.hours6 => const Duration(hours: 6),
    SubscriptionRefreshInterval.hours12 => const Duration(hours: 12),
    SubscriptionRefreshInterval.hours24 => const Duration(hours: 24),
  };
  String get wireValue => name;
  String get label => switch (this) {
    SubscriptionRefreshInterval.off => 'Off',
    SubscriptionRefreshInterval.hours6 => 'Every 6 hours',
    SubscriptionRefreshInterval.hours12 => 'Every 12 hours',
    SubscriptionRefreshInterval.hours24 => 'Every 24 hours',
  };
  static SubscriptionRefreshInterval fromWire(String? value) {
    if (value == null || value.isEmpty) return defaultForSubscription;
    return SubscriptionRefreshInterval.values.firstWhere((i) => i.name == value, orElse: () => defaultForSubscription);
  }
}
bool isSubscriptionStale(Profile profile, {DateTime? now}) {
  if (profile.type != ProfileType.subscription) return false;
  final interval = profile.subscriptionRefreshInterval.duration;
  if (interval == null) return false;
  final last = profile.lastSubscriptionFetchAt;
  if (last == null) return true;
  return (now ?? DateTime.now()).difference(last) >= interval;
}
