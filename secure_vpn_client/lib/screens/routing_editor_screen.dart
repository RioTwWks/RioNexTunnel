import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/routing_rules_provider.dart';
import '../utils/routing_config_builder.dart';

class RoutingEditorScreen extends ConsumerWidget {
  const RoutingEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ruleSet = ref.watch(routingRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routingCustomTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(
                  ruleSet.toJson(),
                ),
              ),
            ),
          ),
          PopupMenuButton<RoutingPresetId>(
            onSelected: (p) =>
                ref.read(routingRulesProvider.notifier).applyPreset(p),
            itemBuilder: (context) => RoutingPresetRegistry.all
                .map(
                  (p) => PopupMenuItem(value: p, child: Text(p.displayName)),
                )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addRule(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: ruleSet.rules
            .map(
              (rule) => ListTile(
                title: Text(rule.name ?? rule.type.displayName),
                subtitle: Text(rule.values.join(', ')),
                trailing: Switch(
                  value: rule.enabled,
                  onChanged: (v) => ref
                      .read(routingRulesProvider.notifier)
                      .toggleRule(rule.id, v),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final rule = ref.read(routingRulesProvider.notifier).createEmptyRule();
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.routingAddDomainRule),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.routingDomainHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionAdd),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref.read(routingRulesProvider.notifier).addRule(
        rule.copyWith(values: [controller.text.trim()]),
      );
    }
    controller.dispose();
  }
}
