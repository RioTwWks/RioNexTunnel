import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../l10n/app_localizations.dart';
import '../models/app_log_level.dart';
import '../models/engine_preference.dart';
import '../models/service_mode_preference.dart';
import '../models/vpn_engine.dart';
import '../providers/app_log_level_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/service_mode_provider.dart';
import '../providers/vpn_providers.dart';
import '../screens/advanced_settings_screen.dart';
import '../screens/log_viewer_screen.dart';
import '../screens/privacy_policy_screen.dart';
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

  void _openLogViewer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LogViewerScreen(),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
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
    final serviceMode = ref.watch(serviceModePreferenceProvider);
    final logLevel = ref.watch(appLogLevelProvider);
    final showsVpnWarning =
        serviceMode.showsDesktopVpnWarning(isDesktop: desktopProxy);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final engineSubtitle = preference.isAuto
        ? (_coreVersion.isEmpty
              ? l10n.coreEngineAutoSubtitle
              : l10n.coreEngineActiveAuto(_coreVersion))
        : (_coreVersion.isEmpty ? null : l10n.coreEngineActive(_coreVersion));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: SectionCard(
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
          child: SectionCard(
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
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 105),
          child: Card(
            child: ListTile(
              key: const ValueKey('advanced_settings_tile'),
              leading: Icon(Icons.security_outlined, color: scheme.primary),
              title: Text(l10n.advancedTitle),
              subtitle: Text(l10n.advancedSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAdvancedSettings,
            ),
          ),
        ),
        if (desktopProxy) ...[
          const SizedBox(height: 14),
          const FadeSlideIn(
            delay: Duration(milliseconds: 175),
            child: BrowserHelperCard(),
          ),
        ],
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 210),
          child: SectionCard(
            title: l10n.diagnosticsTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<AppLogLevel>(
                  key: const ValueKey('log_level_selector'),
                  segments: [
                    ButtonSegment(
                      value: AppLogLevel.info,
                      label: Text(l10n.logLevelInfo),
                    ),
                    ButtonSegment(
                      value: AppLogLevel.debug,
                      label: Text(l10n.logLevelDebug),
                    ),
                  ],
                  selected: {logLevel},
                  onSelectionChanged: (selection) => ref
                      .read(appLogLevelProvider.notifier)
                      .setLevel(selection.first),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.list_alt_outlined, color: scheme.primary),
                  title: Text(l10n.viewLogs),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openLogViewer,
                ),
                ListTile(
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
                            await Clipboard.setData(
                              ClipboardData(text: _logPath),
                            );
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 245),
          child: SectionCard(
            title: l10n.privacyTitle,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.privacy_tip_outlined, color: scheme.primary),
              title: Text(l10n.privacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openPrivacyPolicy,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 280),
          child: SectionCard(
            title: l10n.workModeTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ServiceModePreference>(
                  key: const ValueKey('work_mode_selector'),
                  segments: [
                    ButtonSegment(
                      value: ServiceModePreference.auto,
                      label: Text(l10n.engineAuto),
                    ),
                    ButtonSegment(
                      value: ServiceModePreference.proxy,
                      label: Text(l10n.actionProxy),
                    ),
                    ButtonSegment(
                      value: ServiceModePreference.vpn,
                      label: Text(l10n.actionVpn),
                    ),
                  ],
                  selected: {serviceMode},
                  onSelectionChanged: status == VpnStatus.started
                      ? null
                      : (selection) => ref
                          .read(serviceModePreferenceProvider.notifier)
                          .setPreference(selection.first),
                ),
                if (showsVpnWarning) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.splitTunnelDesktopBody,
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
        const FadeSlideIn(
          delay: Duration(milliseconds: 315),
          child: PanelSettingsSection(),
        ),
        if (status == VpnStatus.started &&
            desktopProxy &&
            sessionCredentials != null) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 350),
            child: ProxyCredentialsCard(credentials: sessionCredentials),
          ),
        ],
      ],
    );
  }
}
