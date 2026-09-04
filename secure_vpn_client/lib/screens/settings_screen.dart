import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/engine_preference.dart';
import '../models/split_tunnel_settings.dart';
import '../models/vpn_engine.dart';
import '../models/socks_auth_mode.dart';
import '../providers/panel_providers.dart';
import '../providers/per_app_proxy_provider.dart';
import '../providers/socks_auth_mode_provider.dart';
import '../providers/profile_advanced_provider.dart';
import '../providers/routing_rules_provider.dart';
import '../providers/vpn_providers.dart';
import '../screens/routing_editor_screen.dart';
import '../screens/per_app_proxy_screen.dart';
import '../services/app_log.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/browser_helper_card.dart';
import '../widgets/dns_settings_card.dart';
import '../widgets/kill_switch_card.dart';
import '../widgets/panel_settings_section.dart';
import '../widgets/proxy_credentials_card.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../utils/l10n_helpers.dart';
import '../widgets/split_tunnel_desktop_banner.dart';
import '../widgets/subscription_pinning_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _coreVersion = '';
  String _logPath = '';

  @override
  void initState() {
    super.initState();
    _loadCoreInfo();
    _loadLogPath();
  }

  Future<void> _loadCoreInfo() async {
    final info = await ref.read(vpnServiceProvider).v2rayBox.getCoreInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _coreVersion = '${info['engine'] ?? 'unknown'} ${info['version'] ?? ''}'
          .trim();
    });
  }

  Future<void> _loadLogPath() async {
    final path = await AppLog.logDirectoryPath();
    if (!mounted) {
      return;
    }
    setState(() {
      _logPath = path ?? '';
    });
  }

  Future<void> _onEnginePreferenceChanged(EnginePreference? preference) async {
    if (preference == null) {
      return;
    }
    await ref.read(enginePreferenceProvider.notifier).setPreference(preference);
    if (!preference.isAuto) {
      ref
          .read(engineProvider.notifier)
          .noteActiveEngine(
            preference == EnginePreference.singbox
                ? VpnEngine.singbox
                : VpnEngine.xray,
          );
    }
    await _loadCoreInfo();
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(enginePreferenceProvider);
    final engine = ref.watch(engineProvider);
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final themeMode = ref.watch(themeModeProvider);
    final desktopProxy =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    final sessionCredentials = ref.watch(sessionCredentialsProvider);
    final perAppProxy = ref.watch(perAppProxyProvider);
    final ruDirectDefault = ref.watch(ruDirectRoutingDefaultProvider);
    final customRouting = ref.watch(routingRulesProvider);
    final socksAuthMode = ref.watch(socksAuthModeProvider);
    final panelState = ref.watch(panelStateProvider);
    final androidVpn = !kIsWeb && Platform.isAndroid;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final engineSubtitle = preference.isAuto
        ? (_coreVersion.isEmpty
              ? l10n.coreEngineAutoSubtitle
              : l10n.coreEngineActiveAuto(_coreVersion))
        : (_coreVersion.isEmpty ? null : l10n.coreEngineActive(_coreVersion));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: _SectionCard(
          title: l10n.appearanceTitle,
          subtitle: l10n.appearanceSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ThemeMode>(
            key: const ValueKey('theme_mode_selector'),
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 14),
          Text(
            l10n.languageTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppLocalePreference>(
            key: const ValueKey('locale_selector'),
            segments: [
              ButtonSegment(
                value: AppLocalePreference.system,
                label: Text(l10n.languageSystem),
              ),
              ButtonSegment(
                value: AppLocalePreference.english,
                label: Text(l10n.languageEnglish),
              ),
              ButtonSegment(
                value: AppLocalePreference.russian,
                label: Text(l10n.languageRussian),
              ),
            ],
            selected: {ref.watch(localePreferenceProvider)},
            onSelectionChanged: (selection) => ref
                .read(localePreferenceProvider.notifier)
                .setPreference(selection.first),
          ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 70),
          child: _SectionCard(
          title: l10n.coreEngineTitle,
          subtitle: engineSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<EnginePreference>(
                key: const ValueKey('engine_selector'),
                segments: [
                  ButtonSegment(
                    value: EnginePreference.auto,
                    label: Text(l10n.engineAuto),
                    icon: const Icon(Icons.hdr_auto_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: EnginePreference.xray,
                    label: Text(l10n.engineXray),
                  ),
                  ButtonSegment(
                    value: EnginePreference.singbox,
                    label: Text(l10n.engineSingbox),
                  ),
                ],
                selected: {preference},
                onSelectionChanged: status == VpnStatus.started
                    ? null
                    : (selection) =>
                          _onEnginePreferenceChanged(selection.first),
              ),
              if (preference.isAuto) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.coreEngineUsesUntilAuto(engine.coreName),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (status == VpnStatus.started) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.coreEngineDisconnectBeforeSwitch,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
        if (desktopProxy) ...[
          const SizedBox(height: 14),
          const FadeSlideIn(
            delay: Duration(milliseconds: 140),
            child: BrowserHelperCard(),
          ),
        ],
        if (desktopProxy) ...[
          const SizedBox(height: 14),
          const FadeSlideIn(
            delay: Duration(milliseconds: 175),
            child: SplitTunnelDesktopBanner(),
          ),
        ],
        if (androidVpn) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 175),
            child: _SectionCard(
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
                              icon: const Icon(Icons.verified_user_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: SplitTunnelMode.exclude,
                              label: Text(l10n.splitTunnelBypass),
                              icon: const Icon(Icons.open_in_browser_outlined, size: 18),
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
                                  : l10n.splitTunnelAppsSelectedCount(perAppProxy.selectedPackages.length),
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
        ],
        const SizedBox(height: 14),
        const KillSwitchCard(),
        const SizedBox(height: 14),
        DnsSettingsCard(desktopProxy: desktopProxy),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 175),
          child: _SectionCard(
            title: l10n.advancedSecurityTitle,
            subtitle: l10n.advancedSecuritySubtitle,
            child: const SubscriptionPinningCard(),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 175),
          child: _SectionCard(
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
                        : l10n.censorshipCustomRoutingActiveCount(customRouting.enabledRules.length),
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
          delay: const Duration(milliseconds: 140),
          child: _SectionCard(
          title: l10n.socksAuthTitle,
          subtitle: l10n.socksAuthSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<SocksAuthMode>(
                key: const ValueKey('socks_auth_mode_selector'),
                segments: [
                  ButtonSegment(value: SocksAuthMode.randomPerSession, label: Text(l10n.socksRandomPerSession), icon: const Icon(Icons.shuffle, size: 18)),
                  ButtonSegment(value: SocksAuthMode.staticFromPanel, label: Text(l10n.socksStaticFromPanel), icon: const Icon(Icons.cloud_sync_outlined, size: 18)),
                ],
                selected: {socksAuthMode.isDisableInjection ? SocksAuthMode.randomPerSession : socksAuthMode},
                onSelectionChanged: (s) => ref.read(socksAuthModeProvider.notifier).setMode(s.first),
              ),
              const SizedBox(height: 8),
              Text(socksAuthMode == SocksAuthMode.staticFromPanel ? l10n.socksStaticDesc : l10n.socksRandomDesc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (socksAuthMode == SocksAuthMode.staticFromPanel && !panelState.settings.isConfigured) ...[
                const SizedBox(height: 8),
                Text(l10n.socksStaticUnavailable, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: 8),
              ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.home_outlined, color: scheme.primary), title: Text(l10n.localBindTitle), subtitle: Text(l10n.localBindSubtitle)),
            ],
          ),
        ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 210),
          child: _SectionCard(
          title: l10n.diagnosticsTitle,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.article_outlined, color: scheme.primary),
            title: Text(l10n.logFiles),
            subtitle: Text(
              _logPath.isEmpty
                  ? l10n.logResolving
                  : '$_logPath\n'
                        '${l10n.logAndroidHint}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: l10n.copyPath,
              onPressed: _logPath.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _logPath));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.logPathCopied)),
                      );
                    },
              icon: const Icon(Icons.copy),
            ),
          ),
        ),
        ),
        const SizedBox(height: 14),
        const FadeSlideIn(
          delay: Duration(milliseconds: 245),
          child: PanelSettingsSection(),
        ),
        if (status == VpnStatus.started &&
            desktopProxy &&
            sessionCredentials != null) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            child: ProxyCredentialsCard(credentials: sessionCredentials),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
