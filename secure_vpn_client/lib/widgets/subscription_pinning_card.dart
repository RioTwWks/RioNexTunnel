import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/pinning_config.dart';
import '../providers/pinning_provider.dart';

class SubscriptionPinningCard extends ConsumerWidget {
  const SubscriptionPinningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(pinningProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('subscription_pinning_toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.pinningEnable),
          subtitle: Text(l10n.pinningSubtitle),
          value: config.enabled,
          onChanged: (enabled) =>
              ref.read(pinningProvider.notifier).setEnabled(enabled),
        ),
        if (config.enabled) ...[
          const SizedBox(height: 8),
          Text(
            l10n.pinningFormatHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (config.pinsByHost.isEmpty)
            Text(
              l10n.pinningNoSavedPins,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...config.pinsByHost.entries.map(
              (entry) => _HostPinTile(
                host: entry.key,
                pins: entry.value,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('add_subscription_pin_button'),
              onPressed: () => _showAddPinDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.pinningAddPin),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showAddPinDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final hostController = TextEditingController();
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.pinningAddSpkiTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: hostController,
                  decoration: InputDecoration(
                    labelText: l10n.pinningHost,
                    hintText: 'panel.example.com',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pinningHostRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinController,
                  decoration: InputDecoration(
                    labelText: l10n.pinningSpki,
                    hintText: 'sha256/AAAAAAAA...',
                  ),
                  validator: (value) {
                    if (value == null ||
                        !SubscriptionSpki.isValidPinFormat(value)) {
                      return l10n.pinningSpkiBytesRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(l10n.actionSave),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      await ref.read(pinningProvider.notifier).addPin(
        host: hostController.text,
        pin: pinController.text,
      );
    }

    hostController.dispose();
    pinController.dispose();
  }
}

class _HostPinTile extends ConsumerWidget {
  const _HostPinTile({
    required this.host,
    required this.pins,
  });

  final String host;
  final List<String> pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    host,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.pinningRemoveHost,
                  onPressed: () =>
                      ref.read(pinningProvider.notifier).removeHost(host),
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ),
            ...pins.map(
              (pin) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  SubscriptionSpki.displayPin(pin),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  tooltip: l10n.pinningRemovePin,
                  onPressed: () => ref.read(pinningProvider.notifier).removePin(
                    host: host,
                    pin: pin,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
