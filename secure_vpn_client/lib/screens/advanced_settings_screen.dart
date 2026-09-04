import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../l10n/app_localizations.dart';
import '../models/socks_auth_mode.dart';
import '../models/split_tunnel_settings.dart';
import '../providers/panel_providers.dart';
import '../providers/per_app_proxy_provider.dart';
import '../providers/profile_advanced_provider.dart';
import '../providers/routing_rules_provider.dart';
import '../providers/socks_auth_mode_provider.dart';
import '../providers/vpn_providers.dart';
import '../utils/l10n_helpers.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/dns_settings_card.dart';
import '../widgets/kill_switch_card.dart';
import '../widgets/section_card.dart';
import '../widgets/split_tunnel_desktop_banner.dart';
import '../widgets/subscription_pinning_card.dart';
import 'per_app_proxy_screen.dart';
import 'routing_editor_screen.dart';

class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final desktopProxy =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    final androidVpn = !kIsWeb && Platform.isAndroid;
    final perAppProxy = ref.watch(perAppProxyProvider);
    final ruDirectDefault = ref.watch(ruDirectRoutingDefaultProvider);
    final customRouting = ref.watch(routingRulesProvider);
    final socksAuthMode = ref.watch(socksAuthModeProvider);
    final panelState = ref.watch(panelStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (desktopProxy) ...[
            const FadeSlideIn(
              child: SplitTunnelDesktopBanner(),
            ),
            const SizedBox(height: 14),
          ],
          if (androidVpn) ...[
            FadeSlideIn(
              child: SectionCard(
                title: l10n.splitTunnelTitle,
                subtitle: l10n.splitTunnelSubtitleAndroid,
                child: perAppProxy.loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<SplitTunnelMode>(
                            key: const ValueKey('split_tunnel_mode_selector'),
                            segments: [
                              ButtonSegment(
                                value: SplitTunnelMode.off,
                                label: Text(l10n.actionOff),
                                icon: const Icon(Icons.public_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: SplitTunnelMode.include,
                                label: Text(l10n.splitTunnelVpnOnly),
                                icon: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 18,
                                ),
                              ),
                              ButtonSegment(
                                value: SplitTunnelMode.exclude,
                                label: Text(l10n.splitTunnelBypass),
                                icon: const Icon(
                                  Icons.open_in_browser_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                            selected: {perAppProxy.mode},
                            onSelectionChanged: (selection) => ref
                                .read(perAppProxyProvider.notifier)
                                .setMode(selection.first),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            splitTunnelModeDescription(l10n, perAppProxy.mode),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          if (perAppProxy.isEnabled) ...[
                            const SizedBox(height: 8),
                            ListTile(
                              key: const ValueKey('manage_split_tunnel_apps'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.apps_outlined,
                                color: scheme.primary,
                              ),
                              title: Text(
                                perAppProxy.isIncludeMode
                                    ? l10n.splitTunnelAppsUsingVpn
                                    : l10n.splitTunnelAppsBypassingVpn,
                              ),
                              subtitle: Text(
                                perAppProxy.selectedPackages.isEmpty
                                    ? l10n.splitTunnelNoAppsSelected
                                    : l10n.splitTunnelAppsSelectedCount(
                                        perAppProxy.selectedPackages.length,
                                      ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PerAppProxyScreen(
                                      mode: perAppProxy.mode,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (status == VpnStatus.started)
                              Text(
                                l10n.splitTunnelReconnectAfterChange,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const FadeSlideIn(
            delay: Duration(milliseconds: 70),
            child: KillSwitchCard(),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 105),
            child: DnsSettingsCard(desktopProxy: desktopProxy),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: SectionCard(
              title: l10n.advancedSecurityTitle,
              subtitle: l10n.advancedSecuritySubtitle,
              child: const SubscriptionPinningCard(),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 175),
            child: SectionCard(
              title: l10n.censorshipResistanceTitle,
              subtitle: l10n.censorshipResistanceSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const ValueKey('ru_direct_default_toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.censorshipRuDirectDefault),
                    subtitle: Text(l10n.censorshipRuDirectDefaultSubtitle),
                    value: ruDirectDefault,
                    onChanged: (enabled) => ref
                        .read(ruDirectRoutingDefaultProvider.notifier)
                        .setEnabled(enabled),
                  ),
                  ListTile(
                    key: const ValueKey('custom_routing_editor_tile'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.alt_route_outlined, color: scheme.primary),
                    title: Text(l10n.censorshipCustomRouting),
                    subtitle: Text(
                      customRouting.rules.isEmpty
                          ? l10n.censorshipCustomRoutingEmpty
                          : l10n.censorshipCustomRoutingActiveCount(
                              customRouting.enabledRules.length,
                            ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RoutingEditorScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.menu_book_outlined, color: scheme.primary),
                    title: Text(l10n.censorshipStackGuide),
                    subtitle: Text(l10n.censorshipStackGuideSubtitle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 210),
            child: SectionCard(
              title: l10n.socksAuthTitle,
              subtitle: l10n.socksAuthSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<SocksAuthMode>(
                    key: const ValueKey('socks_auth_mode_selector'),
                    segments: [
                      ButtonSegment(
                        value: SocksAuthMode.randomPerSession,
                        label: Text(l10n.socksRandomPerSession),
                        icon: const Icon(Icons.shuffle, size: 18),
                      ),
                      ButtonSegment(
                        value: SocksAuthMode.staticFromPanel,
                        label: Text(l10n.socksStaticFromPanel),
                        icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                      ),
                    ],
                    selected: {
                      socksAuthMode.isDisableInjection
                          ? SocksAuthMode.randomPerSession
                          : socksAuthMode,
                    },
                    onSelectionChanged: (s) => ref
                        .read(socksAuthModeProvider.notifier)
                        .setMode(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    socksAuthMode == SocksAuthMode.staticFromPanel
                        ? l10n.socksStaticDesc
                        : l10n.socksRandomDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (socksAuthMode == SocksAuthMode.staticFromPanel &&
                      !panelState.settings.isConfigured) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.socksStaticUnavailable,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.home_outlined, color: scheme.primary),
                    title: Text(l10n.localBindTitle),
                    subtitle: Text(l10n.localBindSubtitle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
