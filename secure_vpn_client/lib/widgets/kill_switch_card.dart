import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kill_switch_mode.dart';
import '../providers/kill_switch_provider.dart';
import '../providers/per_app_proxy_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_entrance.dart';

class KillSwitchCard extends ConsumerWidget {
  const KillSwitchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(killSwitchModeProvider);
    final perAppProxy = ref.watch(perAppProxyProvider);
    final scheme = Theme.of(context).colorScheme;
    final androidVpn = !kIsWeb && Platform.isAndroid;
    final iosVpn = !kIsWeb && Platform.isIOS;
    final desktopProxy =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

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
                  ),
                ],
                onSelectionChanged: (selection) {
                  ref
                      .read(killSwitchModeProvider.notifier)
                      .setMode(selection.first);
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
              if (mode == KillSwitchMode.adaptive) ...[
                Text(
                  l10n.killSwitchAdaptiveDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (desktopProxy) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.killSwitchAdaptiveDesktopNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                if (iosVpn) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.killSwitchAdaptiveIosNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (androidVpn &&
                    perAppProxy.isEnabled &&
                    perAppProxy.selectedPackages.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.killSwitchAdaptiveNoApps,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                if (androidVpn) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.tune_outlined, color: scheme.primary),
                    title: Text(l10n.killSwitchAdaptiveSplitTunnelLink),
                    subtitle: Text(l10n.killSwitchAdaptiveSubtitle),
                    dense: true,
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
