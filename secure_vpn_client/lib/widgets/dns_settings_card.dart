import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../l10n/app_localizations.dart';
import '../models/dns_settings.dart';
import '../providers/dns_settings_provider.dart';
import '../providers/vpn_providers.dart';
import '../services/dns_leak_probe.dart';
import 'animated_entrance.dart';

class DnsSettingsCard extends ConsumerStatefulWidget {
  const DnsSettingsCard({super.key, required this.desktopProxy});
  final bool desktopProxy;

  @override
  ConsumerState<DnsSettingsCard> createState() => _DnsSettingsCardState();
}

class _DnsSettingsCardState extends ConsumerState<DnsSettingsCard> {
  bool _running = false;
  DnsLeakProbeResult? _result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(dnsSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 120),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dnsAdvancedTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.desktopProxy
                    ? l10n.dnsDesktopSubtitle
                    : l10n.dnsVpnSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<DnsMode>(
                key: const ValueKey('dns_mode_selector'),
                segments: [
                  ButtonSegment(
                    value: DnsMode.defaultMode,
                    label: Text(l10n.dnsDefault),
                  ),
                  ButtonSegment(
                    value: DnsMode.custom,
                    label: Text(l10n.dnsCustom),
                  ),
                  ButtonSegment(
                    value: DnsMode.encrypted,
                    label: Text(l10n.dnsEncrypted),
                  ),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) =>
                    ref.read(dnsSettingsProvider.notifier).setMode(s.first),
              ),
              if (!widget.desktopProxy)
                SwitchListTile(
                  key: const ValueKey('dns_leak_protection_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.dnsLeakProtection),
                  subtitle: Text(l10n.dnsLeakProtectionSubtitle),
                  value: settings.leakProtectionEnabled,
                  onChanged: (v) => ref
                      .read(dnsSettingsProvider.notifier)
                      .setLeakProtection(v),
                ),
              if (settings.mode == DnsMode.encrypted)
                ...DnsSettings.encryptedPresets.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.lock_outline, color: scheme.primary),
                    title: Text(p.label),
                    subtitle: Text(
                      p.kind == DnsUpstreamKind.doh ? l10n.dnsDoh : l10n.dnsDot,
                    ),
                  ),
                ),
              if (settings.mode == DnsMode.custom) ...[
                ...settings.upstreams.asMap().entries.map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(e.value.label),
                        subtitle: Text(e.value.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(dnsSettingsProvider.notifier)
                              .removeCustomUpstreamAt(e.key),
                        ),
                      ),
                    ),
                TextButton.icon(
                  onPressed: _addResolver,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.dnsAddResolver),
                ),
              ],
              const Divider(height: 24),
              FilledButton.tonalIcon(
                key: const ValueKey('dns_leak_test_button'),
                onPressed: _running ? null : _runTest,
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_outlined, size: 18),
                label: Text(l10n.dnsLeakTest),
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _result!.summary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _running = true;
      _result = null;
    });
    final connected =
        (ref.read(vpnStatusProvider).value ?? VpnStatus.stopped) ==
            VpnStatus.started;
    final result = await const DnsLeakProbe().run(vpnConnected: connected);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  Future<void> _addResolver() async {
    final l10n = AppLocalizations.of(context);
    final label = TextEditingController();
    final address = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dnsAddResolverTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: InputDecoration(labelText: l10n.dnsResolverLabel),
            ),
            TextField(
              controller: address,
              decoration: InputDecoration(labelText: l10n.dnsResolverAddress),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionAdd),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final upstream = DnsUpstream.tryParse(
      label: label.text.trim().isEmpty ? l10n.dnsCustomLabel : label.text.trim(),
      raw: address.text,
    );
    if (upstream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dnsInvalidAddress)),
      );
      return;
    }
    await ref.read(dnsSettingsProvider.notifier).addCustomUpstream(upstream);
  }
}
