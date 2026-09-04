import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/engine_preference.dart';
import '../models/vpn_engine.dart';
import '../providers/vpn_providers.dart';
import '../screens/advanced_settings_screen.dart';
import '../services/app_log.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/browser_helper_card.dart';
import '../widgets/panel_settings_section.dart';
import '../widgets/proxy_credentials_card.dart';
import '../widgets/section_card.dart';

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

  void _openAdvancedSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdvancedSettingsScreen(),
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    final engineSubtitle = preference.isAuto
        ? (_coreVersion.isEmpty
              ? 'Auto: pick by availability, subscription format, connect fallback'
              : 'Auto · active: $_coreVersion')
        : (_coreVersion.isEmpty ? null : 'Active: $_coreVersion');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: SectionCard(
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
          child: SectionCard(
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
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 105),
          child: Card(
            child: ListTile(
              key: const ValueKey('advanced_settings_tile'),
              leading: Icon(Icons.security_outlined, color: scheme.primary),
              title: const Text('Advanced'),
              subtitle: const Text(
                'Kill switch, DNS, routing, split tunnel, censorship',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAdvancedSettings,
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
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 175),
          child: SectionCard(
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
          delay: Duration(milliseconds: 210),
          child: PanelSettingsSection(),
        ),
        if (status == VpnStatus.started &&
            desktopProxy &&
            sessionCredentials != null) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 245),
            child: ProxyCredentialsCard(credentials: sessionCredentials),
          ),
        ],
      ],
    );
  }
}
