import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';
import '../widgets/connection_button.dart';
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
    final stats = ref.watch(vpnStatsProvider).value;
    final engine = ref.watch(engineProvider);
    final enginePreference = ref.watch(enginePreferenceProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);
    final sessionCredentials = ref.watch(sessionCredentialsProvider);
    final showProxyCard =
        status == VpnStatus.started &&
        ProxyCredentialsCard.isDesktopProxy &&
        sessionCredentials != null;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusIndicator(status: status),
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
                      : selectedProfile.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedProfile == null
                      ? 'Add a config link or subscription in Profiles'
                      : selectedProfile.type == ProfileType.subscription
                      ? 'Subscription profile'
                      : 'Direct config link',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (selectedProfile != null &&
                    selectedProfile.type == ProfileType.subscription) ...[
                  const SizedBox(height: 14),
                  ServerPickerTile(profile: selectedProfile),
                ],
                if (stats != null && status == VpnStatus.started) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Upload',
                          value: stats.formattedUplinkTotal,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Download',
                          value: stats.formattedDownlinkTotal,
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        if (_connectStatus != null) ...[
          Text(
            _connectStatus!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: ConnectionButton(
            status: status,
            busy: _busy,
            onConnect: _connect,
            onDisconnect: _disconnect,
          ),
        ),
        if (showProxyCard) ...[
          const SizedBox(height: 28),
          ProxyCredentialsCard(
            credentials: sessionCredentials,
            showExtensionHint: true,
            compact: true,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 20),
          Card(
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
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
