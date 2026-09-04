import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/split_tunnel_settings.dart';
import '../models/socks_auth_mode.dart';
import '../providers/panel_providers.dart';
import '../providers/per_app_proxy_provider.dart';
import '../providers/profile_advanced_provider.dart';
import '../providers/routing_rules_provider.dart';
import '../providers/socks_auth_mode_provider.dart';
import '../providers/vpn_providers.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/dns_settings_card.dart';
import '../widgets/kill_switch_card.dart';
import '../widgets/section_card.dart';
import '../widgets/socks_auth_mode_strings.dart';
import '../widgets/split_tunnel_desktop_banner.dart';
import '../widgets/subscription_pinning_card.dart';
import 'per_app_proxy_screen.dart';
import 'routing_editor_screen.dart';

String _splitTunnelModeDescription(SplitTunnelMode mode) {
  switch (mode) {
    case SplitTunnelMode.off:
      return 'All apps use the VPN tunnel.';
    case SplitTunnelMode.include:
      return 'Whitelist: only selected apps are routed through VPN.';
    case SplitTunnelMode.exclude:
      return 'Blacklist: selected apps connect directly without VPN.';
  }
}

class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced'),
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
                title: 'Split tunneling',
                subtitle: 'Choose which apps use the VPN tunnel (Android)',
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
                            segments: const [
                              ButtonSegment(
                                value: SplitTunnelMode.off,
                                label: Text('Off'),
                                icon: Icon(Icons.public_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: SplitTunnelMode.include,
                                label: Text('VPN only'),
                                icon: Icon(Icons.verified_user_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: SplitTunnelMode.exclude,
                                label: Text('Bypass'),
                                icon: Icon(Icons.open_in_browser_outlined, size: 18),
                              ),
                            ],
                            selected: {perAppProxy.mode},
                            onSelectionChanged: (selection) => ref
                                .read(perAppProxyProvider.notifier)
                                .setMode(selection.first),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _splitTunnelModeDescription(perAppProxy.mode),
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
                                    ? 'Apps using VPN'
                                    : 'Apps bypassing VPN',
                              ),
                              subtitle: Text(
                                perAppProxy.selectedPackages.isEmpty
                                    ? 'No apps selected'
                                    : '${perAppProxy.selectedPackages.length} app(s) selected',
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
                                'Reconnect VPN after changing split tunnel apps.',
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
          const FadeSlideIn(
            delay: Duration(milliseconds: 140),
            child: SectionCard(
              title: 'Advanced security',
              subtitle: 'Optional hardening for subscription fetch',
              child: SubscriptionPinningCard(),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 175),
            child: SectionCard(
              title: 'Censorship resistance',
              subtitle: 'Transport presets, uTLS fingerprint, RU routing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const ValueKey('ru_direct_default_toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('RU sites direct (default for new profiles)'),
                    subtitle: const Text(
                      'When censorship wizard is enabled, route Russian sites/IP direct',
                    ),
                    value: ruDirectDefault,
                    onChanged: (enabled) => ref
                        .read(ruDirectRoutingDefaultProvider.notifier)
                        .setEnabled(enabled),
                  ),
                  ListTile(
                    key: const ValueKey('custom_routing_editor_tile'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.alt_route_outlined, color: scheme.primary),
                    title: const Text('Custom routing rules'),
                    subtitle: Text(
                      customRouting.rules.isEmpty
                          ? 'Domain, IP, geosite/geoip — import/export JSON'
                          : '${customRouting.enabledRules.length} active rule(s)',
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
                    title: const Text('When to use which stack'),
                    subtitle: const Text(
                      'docs/en/censorship_resistance.md — REALITY vs TLS, XHTTP, mux',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 210),
            child: SectionCard(
              title: SocksAuthModeStrings.sectionTitle(locale),
              subtitle: SocksAuthModeStrings.sectionSubtitle(locale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<SocksAuthMode>(
                    key: const ValueKey('socks_auth_mode_selector'),
                    segments: [
                      ButtonSegment(
                        value: SocksAuthMode.randomPerSession,
                        label: Text(SocksAuthModeStrings.randomPerSession(locale)),
                        icon: const Icon(Icons.shuffle, size: 18),
                      ),
                      ButtonSegment(
                        value: SocksAuthMode.staticFromPanel,
                        label: Text(SocksAuthModeStrings.staticFromPanel(locale)),
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
                        ? SocksAuthModeStrings.staticDescription(locale)
                        : SocksAuthModeStrings.randomDescription(locale),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (socksAuthMode == SocksAuthMode.staticFromPanel &&
                      !panelState.settings.isConfigured) ...[
                    const SizedBox(height: 8),
                    Text(
                      SocksAuthModeStrings.staticUnavailable(locale),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.home_outlined, color: scheme.primary),
                    title: Text(
                      locale.languageCode == 'ru' ? 'Привязка' : 'Local bind',
                    ),
                    subtitle: Text(
                      locale.languageCode == 'ru'
                          ? 'Только 127.0.0.1, пароль обязателен'
                          : '127.0.0.1 only, password required',
                    ),
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
