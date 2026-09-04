import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/connection_detail.dart';
import '../models/engine_preference.dart';
import '../models/profile.dart';
import '../models/vpn_engine.dart';
import '../providers/vpn_providers.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/connection_button.dart';
import '../widgets/multihop_picker_tile.dart';
import '../widgets/proxy_credentials_card.dart';
import '../widgets/server_picker_tile.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;
  String? _error;
  String? _connectStatus;

  Future<void> _connect() async {
    final profile = ref.read(selectedProfileProvider);
    if (profile == null) {
      setState(() => _error = 'Select or add a profile first');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _connectStatus = profile.type == ProfileType.subscription &&
              profile.autoSelectBestServer
          ? 'Testing servers…'
          : null;
    });

    try {
      final result = await ref.read(vpnServiceProvider).connect(profile);
      ref.read(engineProvider.notifier).noteActiveEngine(result.engine);
      final connectedProfile = result.profile;
      await ref.read(profilesProvider.notifier).markLastUsed(connectedProfile.id);
      if (connectedProfile.autoSelectBestServer ||
          connectedProfile.selectedServerIndex != profile.selectedServerIndex) {
        final updated = await ref
            .read(profilesProvider.notifier)
            .selectServer(
              profileId: connectedProfile.id,
              serverIndex: connectedProfile.selectedServerIndex,
              serverName: connectedProfile.selectedServerName,
              autoSelectBestServer: connectedProfile.autoSelectBestServer,
            );
        if (updated != null) {
          await ref.read(selectedProfileProvider.notifier).select(updated);
        }
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _connectStatus = null;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(vpnServiceProvider).disconnect();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final connectionDetail = ref.watch(connectionDetailProvider).value;
    final stats = ref.watch(vpnStatsProvider).value;
    final uptime = ref.watch(connectionUptimeProvider).value;
    final engine = ref.watch(engineProvider);
    final enginePreference = ref.watch(enginePreferenceProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);
    final favoriteProfiles = ref.watch(favoriteProfilesProvider);
    final sessionCredentials = ref.watch(sessionCredentialsProvider);
    final showProxyCard =
        status == VpnStatus.started &&
        ProxyCredentialsCard.isDesktopProxy &&
        sessionCredentials != null;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status == VpnStatus.started;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: _StatusCard(
            status: status,
            connectionDetail: connectionDetail,
            connected: connected,
            isDark: isDark,
            scheme: scheme,
            enginePreference: enginePreference,
            engine: engine,
            selectedProfile: selectedProfile,
            stats: stats,
            uptime: uptime,
          ),
        ),
        if (favoriteProfiles.isNotEmpty) ...[const SizedBox(height: 16), FadeSlideIn(delay: const Duration(milliseconds: 60), child: Wrap(spacing: 8, runSpacing: 8, children: favoriteProfiles.map((p) => FilterChip(label: Text(p.name), selected: selectedProfile?.id == p.id, onSelected: (_) => ref.read(selectedProfileProvider.notifier).select(p))).toList())),],
        const SizedBox(height: 32),
        if (_connectStatus != null) ...[
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              _connectStatus!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: Center(
            child: ConnectionButton(
              status: status,
              busy: _busy,
              onConnect: _connect,
              onDisconnect: _disconnect,
            ),
          ),
        ),
        if (showProxyCard) ...[
          const SizedBox(height: 28),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: ProxyCredentialsCard(
              credentials: sessionCredentials,
              showExtensionHint: true,
              compact: true,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 20),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.connectionDetail,
    required this.connected,
    required this.isDark,
    required this.scheme,
    required this.enginePreference,
    required this.engine,
    required this.selectedProfile,
    required this.stats,
    required this.uptime,
  });

  final VpnStatus status;
  final ConnectionDetail? connectionDetail;
  final bool connected;
  final bool isDark;
  final ColorScheme scheme;
  final EnginePreference enginePreference;
  final VpnEngine engine;
  final Profile? selectedProfile;
  final VpnStats? stats;
  final Duration? uptime;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: connected
                ? [
                    scheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.5),
                    scheme.surfaceContainer,
                  ]
                : [
                    scheme.surfaceContainer,
                    scheme.surfaceContainerLow,
                  ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusIndicator(
                    status: status,
                    detail: connectionDetail,
                  ),
                  const Spacer(),
                  _MetaChip(
                    icon: enginePreference.isAuto
                        ? Icons.hdr_auto_outlined
                        : Icons.memory_outlined,
                    label: enginePreference.isAuto
                        ? 'auto · ${engine.coreName}'
                        : engine.coreName,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                selectedProfile == null
                    ? 'No profile selected'
                    : selectedProfile!.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedProfile == null
                    ? 'Add a config link or subscription in Profiles'
                    : selectedProfile!.type == ProfileType.subscription
                        ? 'Subscription profile'
                        : 'Direct config link',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (selectedProfile != null &&
                  selectedProfile!.type == ProfileType.subscription) ...[
                const SizedBox(height: 14),
                ServerPickerTile(profile: selectedProfile!),
                const SizedBox(height: 10),
                MultihopPickerTile(profile: selectedProfile!),
              ],
              if (stats != null && connected) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Upload',
                        value: stats!.formattedUplinkTotal,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Download',
                        value: stats!.formattedDownlinkTotal,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                  ],
                ),
                if (uptime != null) ...[
                  const SizedBox(height: 10),
                  _StatTile(
                    label: 'Uptime',
                    value: _formatUptime(uptime!),
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatUptime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
          ),
        ],
      ),
    );
  }
}
