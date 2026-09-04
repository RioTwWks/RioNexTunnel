import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/panel_providers.dart';
import '../services/panel_manager.dart';
import '../l10n/app_localizations.dart';
import 'panel_status_card.dart';

class PanelSettingsSection extends ConsumerStatefulWidget {
  const PanelSettingsSection({super.key});

  @override
  ConsumerState<PanelSettingsSection> createState() =>
      _PanelSettingsSectionState();
}

class _PanelSettingsSectionState extends ConsumerState<PanelSettingsSection> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(panelBootstrapProvider);
    final panel = ref.watch(panelStateProvider);
    final l10n = AppLocalizations.of(context)!;
    final settings = panel.settings;

    if (_urlController.text.isEmpty && (settings.panelUrl?.isNotEmpty ?? false)) {
      _urlController.text = settings.panelUrl!;
    }

    return _SectionCard(
      title: l10n.panelSectionTitle,
      subtitle: l10n.panelSectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('panel_enable_toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.panelEnable),
            value: settings.enabled,
            onChanged: panel.busy
                ? null
                : (enabled) async {
                    await ref
                        .read(panelStateProvider.notifier)
                        .setEnabled(enabled);
                  },
          ),
          if (settings.enabled) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('panel_url_field'),
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.panelUrl,
                hintText: 'https://panel.example.com',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _saveUrl(),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('panel_pairing_token_field'),
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: l10n.panelPairingToken,
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('panel_register_button'),
                  onPressed: panel.busy ? null : _register,
                  icon: panel.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(l10n.panelRegister),
                ),
                if (settings.isConfigured)
                  OutlinedButton.icon(
                    key: const ValueKey('panel_refresh_button'),
                    onPressed: panel.busy ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.panelRefresh),
                  ),
                if (settings.deviceToken != null)
                  TextButton(
                    key: const ValueKey('panel_clear_button'),
                    onPressed: panel.busy ? null : _clear,
                    child: Text(l10n.panelClear),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const PanelStatusCard(),
          ],
        ],
      ),
    );
  }

  Future<void> _saveUrl() async {
    await ref
        .read(panelStateProvider.notifier)
        .savePanelUrl(_urlController.text);
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    await _saveUrl();
    try {
      await ref
          .read(panelStateProvider.notifier)
          .register(_tokenController.text);
      _tokenController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.panelRegistered)),
      );
    } on PanelApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.panelRegisterFailed}: '
              '${error.message}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(panelStateProvider.notifier).refreshConfig();
    } on PanelApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _clear() async {
    await ref.read(panelStateProvider.notifier).clearRegistration();
    _tokenController.clear();
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
