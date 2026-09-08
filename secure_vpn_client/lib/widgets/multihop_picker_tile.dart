import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/multihop_chain.dart';
import '../models/profile.dart';
import '../models/subscription_server.dart';
import '../providers/vpn_providers.dart';

class MultihopPickerTile extends ConsumerWidget {
  const MultihopPickerTile({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              key: const ValueKey('multihop_toggle'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.layers_outlined, color: scheme.primary),
              title: Text(l10n.multihopTitle),
              subtitle: Text(
                _hopSummary(l10n, profile),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: profile.multihopEnabled,
              onChanged: (enabled) => ref.read(profilesProvider.notifier).updateProfile(
                profile.copyWith(
                  multihopEnabled: enabled,
                  clearHopServerIndices: !enabled,
                ),
              ),
            ),
            if (profile.multihopEnabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('multihop_pick_hops'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _MultihopHopSheet(profile: profile),
                  ),
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: Text(l10n.multihopEditChain),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _hopSummary(AppLocalizations l10n, Profile profile) {
    if (!profile.multihopEnabled) {
      return l10n.multihopRouteMultiple;
    }
    if (profile.hopServerIndices.isEmpty) {
      return l10n.multihopSelectHops;
    }
    final hops = profile.hopServerIndices
        .map((i) => l10n.serverNumber(i + 1))
        .join(' → ');
    return l10n.multihopEntryChain(profile.selectedServerIndex + 1, hops);
  }
}

class _MultihopHopSheet extends ConsumerStatefulWidget {
  const _MultihopHopSheet({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_MultihopHopSheet> createState() => _MultihopHopSheetState();
}

class _MultihopHopSheetState extends ConsumerState<_MultihopHopSheet> {
  late Future<List<SubscriptionServer>> _serversFuture;
  late List<int> _selectedHops;

  @override
  void initState() {
    super.initState();
    _selectedHops = List<int>.from(widget.profile.hopServerIndices);
    _serversFuture = ref.read(vpnServiceProvider).listSubscriptionServers(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.multihopChainTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<SubscriptionServer>>(
              future: _serversFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final servers = snapshot.data!;
                if (servers.length < 2) {
                  return Text(l10n.multihopRequiresTwoServers);
                }
                final selectable = servers.where(
                  (s) => s.index != widget.profile.selectedServerIndex,
                );
                return Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectable.length,
                    itemBuilder: (context, index) {
                      final server = selectable.elementAt(index);
                      return CheckboxListTile(
                        value: _selectedHops.contains(server.index),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selectedHops.add(server.index);
                          } else {
                            _selectedHops.remove(server.index);
                          }
                        }),
                        title: Text(server.name),
                        subtitle: Text(l10n.serverNumber(server.index + 1)),
                      );
                    },
                  ),
                );
              },
            ),
            FilledButton(
              onPressed: _selectedHops.isEmpty ? null : _save,
              child: Text(l10n.multihopSaveChain),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final servers = await _serversFuture;
    try {
      MultihopChain.validateProfile(
        widget.profile.copyWith(
          multihopEnabled: true,
          hopServerIndices: _selectedHops,
        ),
        serverCount: servers.length,
      );
    } on MultihopChainException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    await ref.read(profilesProvider.notifier).updateProfile(
      widget.profile.copyWith(
        multihopEnabled: true,
        hopServerIndices: List<int>.from(_selectedHops),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
