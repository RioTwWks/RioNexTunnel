import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';
import '../models/dns_settings.dart';
import '../providers/dns_settings_provider.dart';
import '../providers/vpn_providers.dart';
import '../services/dns_leak_probe.dart';
import 'animated_entrance.dart';

class DnsSettingsCard extends ConsumerStatefulWidget {
  const DnsSettingsCard({super.key, required this.desktopProxy});
  final bool desktopProxy;
  @override ConsumerState<DnsSettingsCard> createState() => _DnsSettingsCardState();
}

class _DnsSettingsCardState extends ConsumerState<DnsSettingsCard> {
  bool _running = false; DnsLeakProbeResult? _result;
  @override Widget build(BuildContext context) {
    final settings = ref.watch(dnsSettingsProvider); final scheme = Theme.of(context).colorScheme;
    return FadeSlideIn(delay: const Duration(milliseconds: 120), child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Advanced DNS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(widget.desktopProxy ? 'Desktop proxy mode does not intercept system DNS. See docs/en/dns.md' : 'DoH/DoT upstreams and leak protection for VPN/TUN mode', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      SegmentedButton<DnsMode>(key: const ValueKey('dns_mode_selector'), segments: const [ButtonSegment(value: DnsMode.defaultMode, label: Text('Default')), ButtonSegment(value: DnsMode.custom, label: Text('Custom')), ButtonSegment(value: DnsMode.encrypted, label: Text('Encrypted'))], selected: {settings.mode}, onSelectionChanged: (s) => ref.read(dnsSettingsProvider.notifier).setMode(s.first)),
      if (!widget.desktopProxy) SwitchListTile(key: const ValueKey('dns_leak_protection_toggle'), contentPadding: EdgeInsets.zero, title: const Text('DNS leak protection'), subtitle: const Text('Route DNS through the tunnel (TUN mode)'), value: settings.leakProtectionEnabled, onChanged: (v) => ref.read(dnsSettingsProvider.notifier).setLeakProtection(v)),
      if (settings.mode == DnsMode.encrypted) ...DnsSettings.encryptedPresets.map((p) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.lock_outline, color: scheme.primary), title: Text(p.label), subtitle: Text(p.kind == DnsUpstreamKind.doh ? 'DoH' : 'DoT'))),
      if (settings.mode == DnsMode.custom) ...[...settings.upstreams.asMap().entries.map((e) => ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(e.value.label), subtitle: Text(e.value.address), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ref.read(dnsSettingsProvider.notifier).removeCustomUpstreamAt(e.key)))), TextButton.icon(onPressed: _addResolver, icon: const Icon(Icons.add), label: const Text('Add resolver'))],
      const Divider(height: 24),
      FilledButton.tonalIcon(key: const ValueKey('dns_leak_test_button'), onPressed: _running ? null : _runTest, icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_outlined, size: 18), label: const Text('DNS leak test')),
      if (_result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_result!.summary, style: Theme.of(context).textTheme.bodySmall)),
    ]))));
  }
  Future<void> _runTest() async { setState(() { _running = true; _result = null; }); final c = (ref.read(vpnStatusProvider).value ?? VpnStatus.stopped) == VpnStatus.started; final r = await const DnsLeakProbe().run(vpnConnected: c); if (!mounted) return; setState(() { _running = false; _result = r; }); }
  Future<void> _addResolver() async {
    final label = TextEditingController(); final address = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Add DNS resolver'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: label, decoration: const InputDecoration(labelText: 'Label')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))]));
    if (ok != true || !mounted) return;
    final u = DnsUpstream.tryParse(label: label.text.trim().isEmpty ? 'Custom' : label.text.trim(), raw: address.text);
    if (u == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid address'))); return; }
    await ref.read(dnsSettingsProvider.notifier).addCustomUpstream(u);
  }
}
