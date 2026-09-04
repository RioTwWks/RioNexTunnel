import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinning_config.dart';
import '../providers/pinning_provider.dart';

class SubscriptionPinningCard extends ConsumerWidget {
  const SubscriptionPinningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(pinningProvider);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final isRu = locale.languageCode == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('subscription_pinning_toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            isRu
                ? 'Проверка сертификата подписки (SPKI)'
                : 'Subscription certificate pinning (SPKI)',
          ),
          subtitle: Text(
            isRu
                ? 'По умолчанию выключено. Проверяет только хосты с сохранёнными pin.'
                : 'Off by default. Only hosts with saved pins are checked.',
          ),
          value: config.enabled,
          onChanged: (enabled) =>
              ref.read(pinningProvider.notifier).setEnabled(enabled),
        ),
        if (config.enabled) ...[
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Формат pin: sha256/<base64 SHA-256 SPKI>. При смене сертификата панели обновите pin.'
                : 'Pin format: sha256/<base64 SHA-256 SPKI>. Update pins when the panel rotates certificates.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (config.pinsByHost.isEmpty)
            Text(
              isRu ? 'Нет сохранённых pin.' : 'No saved pins yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...config.pinsByHost.entries.map(
              (entry) => _HostPinTile(
                host: entry.key,
                pins: entry.value,
                isRu: isRu,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('add_subscription_pin_button'),
              onPressed: () => _showAddPinDialog(context, ref, isRu: isRu),
              icon: const Icon(Icons.add),
              label: Text(isRu ? 'Добавить pin' : 'Add pin'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showAddPinDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isRu,
  }) async {
    final hostController = TextEditingController();
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isRu ? 'Добавить SPKI pin' : 'Add SPKI pin'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: hostController,
                  decoration: InputDecoration(
                    labelText: isRu ? 'Хост подписки' : 'Subscription host',
                    hintText: 'panel.example.com',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isRu ? 'Укажите хост' : 'Enter a host';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinController,
                  decoration: InputDecoration(
                    labelText: isRu ? 'SPKI pin' : 'SPKI pin',
                    hintText: 'sha256/AAAAAAAA...',
                  ),
                  validator: (value) {
                    if (value == null ||
                        !SubscriptionSpki.isValidPinFormat(value)) {
                      return isRu
                          ? 'Нужен base64 SHA-256 SPKI (32 байта)'
                          : 'Expected base64 SHA-256 SPKI (32 bytes)';
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
              child: Text(isRu ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(isRu ? 'Сохранить' : 'Save'),
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
    required this.isRu,
  });

  final String host;
  final List<String> pins;
  final bool isRu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  tooltip: isRu ? 'Удалить хост' : 'Remove host',
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
                  tooltip: isRu ? 'Удалить pin' : 'Remove pin',
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
