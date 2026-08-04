import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/vpn_engine.dart';
import '../providers/vpn_providers.dart';
import '../services/app_log.dart';
import '../widgets/browser_helper_card.dart';
import '../widgets/proxy_credentials_card.dart';

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

  Future<void> _onEngineChanged(VpnEngine? engine) async {
    if (engine == null) {
      return;
    }
    await ref.read(engineProvider.notifier).setEngine(engine);
    await _loadCoreInfo();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final themeMode = ref.watch(themeModeProvider);
    final desktopProxy = !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    final sessionCredentials = ref.watch(sessionCredentialsProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _SectionCard(
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
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Core engine',
          subtitle: _coreVersion.isEmpty ? null : 'Active: $_coreVersion',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<VpnEngine>(
                key: const ValueKey('engine_selector'),
                segments: const [
                  ButtonSegment(
                    value: VpnEngine.xray,
                    label: Text('Xray'),
                  ),
                  ButtonSegment(
                    value: VpnEngine.singbox,
                    label: Text('sing-box'),
                  ),
                ],
                selected: {engine},
                onSelectionChanged: status == VpnStatus.started
                    ? null
                    : (selection) => _onEngineChanged(selection.first),
              ),
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
        if (desktopProxy) ...[
          const SizedBox(height: 14),
          const BrowserHelperCard(),
        ],
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Security',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline, color: scheme.primary),
                title: const Text('Dynamic SOCKS5 credentials'),
                subtitle: const Text('New username/password every session'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.home_outlined, color: scheme.primary),
                title: const Text('Local bind'),
                subtitle: const Text('127.0.0.1 only, password required'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
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
        if (status == VpnStatus.started &&
            desktopProxy &&
            sessionCredentials != null) ...[
          const SizedBox(height: 14),
          ProxyCredentialsCard(credentials: sessionCredentials),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
