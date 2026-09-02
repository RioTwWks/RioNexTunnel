import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kill_switch_mode.dart';
import '../providers/kill_switch_provider.dart';
import '../widgets/animated_entrance.dart';

class KillSwitchCard extends ConsumerWidget {
  const KillSwitchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(killSwitchModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 105),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kill switch',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Block internet when VPN or core stops unexpectedly',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<KillSwitchMode>(
                key: const ValueKey('kill_switch_mode_selector'),
                segments: const [
                  ButtonSegment(
                    value: KillSwitchMode.off,
                    label: Text('Off'),
                    icon: Icon(Icons.public_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: KillSwitchMode.strict,
                    label: Text('Strict'),
                    icon: Icon(Icons.block_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: KillSwitchMode.adaptive,
                    label: Text('Adaptive'),
                    icon: Icon(Icons.apps_outlined, size: 18),
                    enabled: false,
                  ),
                ],
                onSelectionChanged: (selection) {
                  final picked = selection.first;
                  if (picked == KillSwitchMode.adaptive) {
                    return;
                  }
                  ref.read(killSwitchModeProvider.notifier).setMode(picked);
                },
                selected: {mode},
              ),
              const SizedBox(height: 10),
              if (mode == KillSwitchMode.strict)
                Text(
                  'Strict blocks all outbound traffic when the tunnel or core drops.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: const Text('Adaptive (per-app)'),
                subtitle: const Text(
                  'Requires split tunneling — available after Agent B merges',
                ),
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
