import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/routing_rules_provider.dart';
import '../utils/routing_config_builder.dart';

class RoutingEditorScreen extends ConsumerWidget {
  const RoutingEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleSet = ref.watch(routingRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom routing'),
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
    final rule = ref.read(routingRulesProvider.notifier).createEmptyRule();
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add domain rule'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
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
