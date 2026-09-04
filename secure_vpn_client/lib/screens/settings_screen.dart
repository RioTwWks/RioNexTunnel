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
import '../providers/vpn_providers.dart';
import '../screens/per_app_proxy_screen.dart';
import '../services/app_log.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/browser_helper_card.dart';
import '../widgets/dns_settings_card.dart';
import '../widgets/kill_switch_card.dart';
import '../widgets/panel_settings_section.dart';
import '../widgets/proxy_credentials_card.dart';
import '../widgets/socks_auth_mode_strings.dart';
import '../widgets/split_tunnel_desktop_banner.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

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
    final socksAuthMode = ref.watch(socksAuthModeProvider);
    final panelState = ref.watch(panelStateProvider);
    final androidVpn = !kIsWeb && Platform.isAndroid;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final engineSubtitle = preference.isAuto
        ? (_coreVersion.isEmpty
              ? 'Auto: pick by availability, subscription format, connect fallback'
              : 'Auto · active: $_coreVersion')
        : (_coreVersion.isEmpty ? null : 'Active: $_coreVersion');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: _SectionCard(
          title: 'Appearance',
          subtitle: 'Theme applies on all platforms',
          child: SegmentedButton<ThemeMode>(
            key: const ValueKey('theme_mode_selector'),
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first);
            },
          ),
        ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 70),
          child: _SectionCard(
          title: 'Core engine',
          subtitle: engineSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<EnginePreference>(
                key: const ValueKey('engine_selector'),
                segments: const [
                  ButtonSegment(
                    value: EnginePreference.auto,
                    label: Text('Auto'),
                    icon: Icon(Icons.hdr_auto_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: EnginePreference.xray,
                    label: Text('Xray'),
                  ),
                  ButtonSegment(
                    value: EnginePreference.singbox,
                    label: Text('sing-box'),
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
                  'Uses ${engine.coreName} until the next Auto connect',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (status == VpnStatus.started) ...[
                const SizedBox(height: 10),
                Text(
                  'Disconnect VPN before switching engine',
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
        ],
        const SizedBox(height: 14),
        const KillSwitchCard(),
        const SizedBox(height: 14),
        DnsSettingsCard(desktopProxy: desktopProxy),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 175),
          child: _SectionCard(
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
          delay: const Duration(milliseconds: 140),
          child: _SectionCard(
          title: SocksAuthModeStrings.sectionTitle(locale),
          subtitle: SocksAuthModeStrings.sectionSubtitle(locale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<SocksAuthMode>(
                key: const ValueKey('socks_auth_mode_selector'),
                segments: [
                  ButtonSegment(value: SocksAuthMode.randomPerSession, label: Text(SocksAuthModeStrings.randomPerSession(locale)), icon: const Icon(Icons.shuffle, size: 18)),
                  ButtonSegment(value: SocksAuthMode.staticFromPanel, label: Text(SocksAuthModeStrings.staticFromPanel(locale)), icon: const Icon(Icons.cloud_sync_outlined, size: 18)),
                ],
                selected: {socksAuthMode.isDisableInjection ? SocksAuthMode.randomPerSession : socksAuthMode},
                onSelectionChanged: (s) => ref.read(socksAuthModeProvider.notifier).setMode(s.first),
              ),
              const SizedBox(height: 8),
              Text(socksAuthMode == SocksAuthMode.staticFromPanel ? SocksAuthModeStrings.staticDescription(locale) : SocksAuthModeStrings.randomDescription(locale), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (socksAuthMode == SocksAuthMode.staticFromPanel && !panelState.settings.isConfigured) ...[
                const SizedBox(height: 8),
                Text(SocksAuthModeStrings.staticUnavailable(locale), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: 8),
              ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.home_outlined, color: scheme.primary), title: Text(locale.languageCode == 'ru' ? 'Привязка' : 'Local bind'), subtitle: Text(locale.languageCode == 'ru' ? 'Только 127.0.0.1, пароль обязателен' : '127.0.0.1 only, password required')),
            ],
          ),
        ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 210),
          child: _SectionCard(
          title: 'Diagnostics',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.article_outlined, color: scheme.primary),
            title: const Text('Log files'),
            subtitle: Text(
              _logPath.isEmpty
                  ? 'Resolving…'
                  : '$_logPath\n'
                        'Android also: Android/data/…/files/logs/',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Copy path',
              onPressed: _logPath.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _logPath));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log path copied')),
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
