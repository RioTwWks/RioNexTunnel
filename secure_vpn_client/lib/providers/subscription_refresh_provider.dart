import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../providers/pinning_provider.dart';
import '../providers/vpn_providers.dart';
import '../services/app_log.dart';
import '../services/subscription_refresh_service.dart';
final subscriptionRefreshServiceProvider = Provider((ref) => SubscriptionRefreshService(engine: ref.watch(engineProvider), pinning: ref.watch(pinningProvider)));
final subscriptionRefreshLifecycleProvider = Provider<void>((ref) { final l = _SubscriptionRefreshLifecycle(ref); ref.onDispose(l.dispose); l.start(); });
class _SubscriptionRefreshLifecycle with WidgetsBindingObserver {
  _SubscriptionRefreshLifecycle(this._ref); final Ref _ref; Timer? _timer; bool _busy = false;
  void start() { WidgetsBinding.instance.addObserver(this); _timer = Timer.periodic(const Duration(minutes: 30), (_) => unawaited(_run())); Future.microtask(_run); }
  void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(_run()); }
  Future<void> _run() async { if (_busy) return; _busy = true; try { final s = _ref.read(subscriptionRefreshServiceProvider); for (final p in s.dueProfiles(_ref.read(profilesProvider))) await refreshSubscriptionProfile(_ref, p); } finally { _busy = false; } }
}
Future<SubscriptionRefreshResult> refreshSubscriptionProfile(Ref ref, Profile profile) async {
  final result = await ref.read(subscriptionRefreshServiceProvider).refreshProfile(profile);
  if (result.success) { await ref.read(profilesProvider.notifier).recordSubscriptionFetch(profile.id); AppLog.info('Subscription refreshed profile=${profile.name} servers=${result.serverCount}'); }
  else { AppLog.error('Subscription refresh failed profile=${profile.name}: ${result.errorMessage}'); }
  return result;
}
