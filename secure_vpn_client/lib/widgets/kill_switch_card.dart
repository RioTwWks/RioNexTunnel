import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kill_switch_mode.dart';
import '../providers/kill_switch_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_entrance.dart';

class KillSwitchCard extends ConsumerWidget {
  const KillSwitchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                l10n.killSwitchTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.killSwitchSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<KillSwitchMode>(
                key: const ValueKey('kill_switch_mode_selector'),
                segments: [
                  ButtonSegment(
                    value: KillSwitchMode.off,
                    label: Text(l10n.actionOff),
                    icon: const Icon(Icons.public_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: KillSwitchMode.strict,
                    label: Text(l10n.killSwitchStrict),
                    icon: const Icon(Icons.block_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: KillSwitchMode.adaptive,
                    label: Text(l10n.killSwitchAdaptive),
                    icon: const Icon(Icons.apps_outlined, size: 18),
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
                  l10n.killSwitchStrictDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: Text(l10n.killSwitchAdaptiveTitle),
                subtitle: Text(l10n.killSwitchAdaptiveSubtitle),
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
