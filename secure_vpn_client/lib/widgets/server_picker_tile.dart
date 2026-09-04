import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/subscription_server.dart';
import '../providers/vpn_providers.dart';
import '../utils/subscription_latency_probe.dart';

/// Tap target showing the selected subscription server; opens a picker sheet.
class ServerPickerTile extends ConsumerWidget {
  const ServerPickerTile({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final label = profile.autoSelectBestServer
        ? (profile.selectedServerName != null
              ? 'Automatic · ${profile.selectedServerName}'
              : 'Automatic (best latency)')
        : (profile.selectedServerName ??
              'Server ${profile.selectedServerIndex + 1}');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('server_picker_tile'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                profile.autoSelectBestServer
                    ? Icons.speed_rounded
                    : Icons.dns_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ServerPickerSheet(profile: profile);
      },
    );
  }
}

class _ServerPickerSheet extends ConsumerStatefulWidget {
  const _ServerPickerSheet({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends ConsumerState<_ServerPickerSheet> {
  late Future<List<SubscriptionServer>> _serversFuture;
  final Map<int, int> _latencies = {};
  bool _probing = false;
  String? _probeError;

  @override
  void initState() {
    super.initState();
    _serversFuture = _load();
  }

  Future<List<SubscriptionServer>> _load() {
    return ref
        .read(vpnServiceProvider)
        .listSubscriptionServers(widget.profile, logicalServers: true);
  }

  Future<void> _persistSelection({
    required int serverIndex,
    required String serverName,
    required bool autoSelectBestServer,
  }) async {
    final updated = await ref
        .read(profilesProvider.notifier)
        .selectServer(
          profileId: widget.profile.id,
          serverIndex: serverIndex,
          serverName: serverName,
          autoSelectBestServer: autoSelectBestServer,
        );
    if (updated != null) {
      await ref.read(selectedProfileProvider.notifier).select(updated);
    }
  }

  Future<void> _selectManual(SubscriptionServer server) async {
    await _persistSelection(
      serverIndex: server.index,
      serverName: server.name,
      autoSelectBestServer: false,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectAutomatic({bool closeSheet = true}) async {
    if (_probing) {
      return;
    }
    setState(() {
      _probing = true;
      _probeError = null;
      _latencies.clear();
    });

    try {
      final best = await ref
          .read(vpnServiceProvider)
          .selectBestSubscriptionServer(
            widget.profile,
            onResult: (result) {
              if (!mounted) {
                return;
              }
              setState(() {
                _latencies[result.server.index] = result.latencyMs;
              });
            },
          );
      await _persistSelection(
        serverIndex: best.server.index,
        serverName: best.server.name,
        autoSelectBestServer: true,
      );
      if (mounted && closeSheet) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _probeError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _probing = false);
      }
    }
  }

  Future<void> _probeOnly() async {
    if (_probing) {
      return;
    }
    setState(() {
      _probing = true;
      _probeError = null;
      _latencies.clear();
    });
    try {
      await ref
          .read(vpnServiceProvider)
          .probeSubscriptionServers(
            widget.profile,
            onResult: (result) {
              if (!mounted) {
                return;
              }
              setState(() {
                _latencies[result.server.index] = result.latencyMs;
              });
            },
          );
    } catch (error) {
      if (mounted) {
        setState(() => _probeError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _probing = false);
      }
    }
  }

  String _latencyLabel(int? ms) {
    if (ms == null) {
      return '';
    }
    if (ms < 0) {
      return 'timeout';
    }
    return '${ms}ms';
  }

  Color _latencyColor(BuildContext context, int? ms) {
    final scheme = Theme.of(context).colorScheme;
    return switch (LatencyQuality.fromMs(ms)) {
      LatencyQuality.excellent => const Color(0xFF2ED573),
      LatencyQuality.good => const Color(0xFF7BED9F),
      LatencyQuality.fair => const Color(0xFFFFA502),
      LatencyQuality.poor => scheme.error,
      LatencyQuality.timeout => scheme.outline,
      LatencyQuality.unknown => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final autoSelected = widget.profile.autoSelectBestServer;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select server',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_probing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    key: const ValueKey('server_picker_probe'),
                    tooltip: 'Test latency (URL test)',
                    onPressed: _probing ? null : _probeOnly,
                    icon: const Icon(Icons.network_ping_outlined),
                  ),
                  IconButton(
                    key: const ValueKey('server_picker_refresh'),
                    tooltip: 'Refresh list',
                    onPressed: _probing
                        ? null
                        : () {
                            setState(() {
                              _latencies.clear();
                              _probeError = null;
                              _serversFuture = _load();
                            });
                          },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (_probeError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _probeError!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<SubscriptionServer>>(
                future: _serversFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        snapshot.error.toString(),
                        style: TextStyle(color: scheme.error),
                      ),
                    );
                  }
                  final servers = snapshot.data ?? const [];
                  if (servers.isEmpty) {
                    return const Center(child: Text('No servers found'));
                  }

                  final sorted = List<SubscriptionServer>.from(servers);
                  if (_latencies.isNotEmpty) {
                    sorted.sort((a, b) {
                      final la = _latencies[a.index] ?? 1 << 30;
                      final lb = _latencies[b.index] ?? 1 << 30;
                      final na = la < 0 ? 1 << 30 : la;
                      final nb = lb < 0 ? 1 << 30 : lb;
                      final cmp = na.compareTo(nb);
                      return cmp != 0 ? cmp : a.index.compareTo(b.index);
                    });
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: sorted.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _AutomaticServerTile(
                          selected: autoSelected,
                          probing: _probing,
                          lastServerName: widget.profile.selectedServerName,
                          onTap: () => _selectAutomatic(),
                        );
                      }

                      final server = sorted[index - 1];
                      final selected =
                          !autoSelected &&
                          server.index == widget.profile.selectedServerIndex;
                      final latency = _latencies[server.index];
                      final latencyText = _latencyLabel(latency);
                      final latencyColor = _latencyColor(context, latency);

                      return ListTile(
                        key: ValueKey('server_option_${server.index}'),
                        selected: selected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected ? scheme.primary : null,
                        ),
                        title: Text(server.name),
                        subtitle: Text(
                          latencyText.isEmpty
                              ? 'Server ${server.index + 1}'
                              : 'Server ${server.index + 1} · $latencyText',
                        ),
                        trailing: latencyText.isEmpty
                            ? null
                            : Text(
                                latencyText,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: latencyColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                        onTap: _probing ? null : () => _selectManual(server),
                      );
                    },
                  );
                },
              ),
            ),
            if (autoSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Automatic: best server is re-tested on each Connect',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticServerTile extends StatelessWidget {
  const _AutomaticServerTile({
    required this.selected,
    required this.probing,
    required this.onTap,
    this.lastServerName,
  });

  final bool selected;
  final bool probing;
  final VoidCallback onTap;
  final String? lastServerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = lastServerName != null
        ? 'Last: $lastServerName · re-tested on Connect'
        : 'Pick the lowest-latency server on Connect';

    return ListTile(
      key: const ValueKey('server_picker_auto'),
      selected: selected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      tileColor: selected ? scheme.primaryContainer.withValues(alpha: 0.25) : null,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.speed_rounded,
        color: selected ? scheme.primary : scheme.secondary,
      ),
      title: const Text('Automatic'),
      subtitle: Text(subtitle),
      trailing: probing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: probing ? null : onTap,
    );
  }
}
