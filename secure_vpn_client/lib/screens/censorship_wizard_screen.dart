import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../providers/profile_advanced_provider.dart';
import '../utils/transport_presets.dart';
import '../widgets/transport_stack_chip.dart';

class CensorshipWizardResult {
  const CensorshipWizardResult({
    required this.enabled,
    this.preset,
    this.fingerprint = TransportPresets.defaultFingerprint,
    this.muxEnabled = false,
    this.muxConcurrency = TransportPresets.defaultMuxConcurrency,
    this.ruDirectRouting = false,
    this.updatedLink,
  });

  final bool enabled;
  final TransportPresetId? preset;
  final TlsFingerprint fingerprint;
  final bool muxEnabled;
  final int muxConcurrency;
  final bool ruDirectRouting;
  final String? updatedLink;
}

class CensorshipWizardScreen extends ConsumerStatefulWidget {
  const CensorshipWizardScreen({
    super.key,
    required this.profileName,
    required this.configLink,
    required this.profileType,
    this.initial,
  });

  final String profileName;
  final String configLink;
  final ProfileType profileType;
  final Profile? initial;

  @override
  ConsumerState<CensorshipWizardScreen> createState() =>
      _CensorshipWizardScreenState();
}

class _CensorshipWizardScreenState
    extends ConsumerState<CensorshipWizardScreen> {
  late bool _enabled;
  late TransportPresetId _preset;
  late TlsFingerprint _fingerprint;
  late bool _muxEnabled;
  late bool _ruDirectRouting;
  late DetectedTransport _detected;

  @override
  void initState() {
    super.initState();
    _detected = TransportPresets.detectFromContent(widget.configLink);
    final initial = widget.initial;
    _enabled = initial?.censorshipModeEnabled ?? false;
    _preset = initial?.transportPreset ??
        TransportPresets.suggestPreset(widget.configLink);
    _fingerprint = initial?.tlsFingerprint ??
        TlsFingerprintJson.fromWire(_detected.fingerprint);
    _muxEnabled = initial?.muxEnabled ?? false;
    _ruDirectRouting = initial?.ruDirectRouting ??
        ref.read(ruDirectRoutingDefaultProvider);
  }

  Profile get _previewProfile => Profile(
        id: 'preview',
        name: widget.profileName,
        configLink: widget.configLink,
        type: widget.profileType,
        censorshipModeEnabled: _enabled,
        transportPreset: _preset,
        tlsFingerprint: _fingerprint,
        muxEnabled: _muxEnabled,
        ruDirectRouting: _ruDirectRouting,
      );

  void _finish() {
    String? updatedLink;
    if (_enabled &&
        widget.profileType == ProfileType.link &&
        widget.configLink.contains('://')) {
      updatedLink = TransportPresets.applyPresetToLink(
        widget.configLink,
        preset: _preset,
        fingerprint: _fingerprint,
      );
    }
    Navigator.of(context).pop(
      CensorshipWizardResult(
        enabled: _enabled,
        preset: _enabled ? _preset : null,
        fingerprint: _fingerprint,
        muxEnabled: _muxEnabled,
        ruDirectRouting: _ruDirectRouting,
        updatedLink: updatedLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Censorship mode'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profileName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detected: ${_detected.stackSummary}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (_detected.xhttpMode == 'auto') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Warning: XHTTP mode "auto" is unreliable — wizard uses stream-one.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TransportStackChip(
                    profile: _previewProfile,
                    content: widget.configLink,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable censorship mode'),
            subtitle: const Text(
              'Transport presets, uTLS fingerprint, optional RU routing',
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            Text(
              'Transport preset',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            ...TransportPresets.wizardOrder.map(
              (preset) => RadioListTile<TransportPresetId>(
                value: preset,
                groupValue: _preset,
                onChanged: (v) => setState(() => _preset = v!),
                title: Text(preset.label),
                subtitle: Text(preset.description),
              ),
            ),
            const Divider(height: 24),
            Text(
              'TLS fingerprint (uTLS)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TlsFingerprint.values.map((fp) {
                return ChoiceChip(
                  label: Text(fp.wireValue),
                  selected: _fingerprint == fp,
                  onSelected: (_) => setState(() => _fingerprint = fp),
                );
              }).toList(),
            ),
            SwitchListTile(
              title: const Text('Enable mux'),
              subtitle: const Text('Mobile fallback — concurrency 8'),
              value: _muxEnabled,
              onChanged: (v) => setState(() => _muxEnabled = v),
            ),
            SwitchListTile(
              title: const Text('RU sites direct'),
              subtitle: const Text('geosite:ru / geoip:ru → direct (needs geo)'),
              value: _ruDirectRouting,
              onChanged: (v) => setState(() => _ruDirectRouting = v),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}
