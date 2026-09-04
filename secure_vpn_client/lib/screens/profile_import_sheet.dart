import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../providers/vpn_providers.dart';
import '../screens/censorship_wizard_screen.dart';
import '../services/profile_import_service.dart';

class ProfileImportSheet extends ConsumerStatefulWidget {
  const ProfileImportSheet({super.key, required this.candidates});
  final List<ProfileImportCandidate> candidates;

  @override
  ConsumerState<ProfileImportSheet> createState() => _ProfileImportSheetState();
}

class _ProfileImportSheetState extends ConsumerState<ProfileImportSheet> {
  late final List<_EditableCandidate> _items;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _items = widget.candidates
        .map((c) => _EditableCandidate(
              candidate: c,
              nameController: TextEditingController(text: c.suggestedName),
              selected: true,
            ))
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.nameController.dispose();
    }
    super.dispose();
  }

  Future<void> _importSelected() async {
    final selected = _items.where((i) => i.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one profile to import')),
      );
      return;
    }
    setState(() => _importing = true);
    var imported = 0;
    try {
      for (final item in selected) {
        final name = item.nameController.text.trim();
        if (name.isEmpty) continue;
        CensorshipWizardResult? wizardResult;
        if (item.candidate.type == ProfileType.link) {
          if (!mounted) {
            return;
          }
          wizardResult = await Navigator.of(context).push<CensorshipWizardResult>(
            MaterialPageRoute(
              builder: (_) => CensorshipWizardScreen(
                profileName: name,
                configLink: item.candidate.link,
                profileType: item.candidate.type,
              ),
            ),
          );
        }
        await ref.read(profilesProvider.notifier).addProfile(
              name: name,
              configLink: wizardResult?.updatedLink ?? item.candidate.link,
              type: item.candidate.type,
              censorshipModeEnabled: wizardResult?.enabled ?? false,
              transportPreset: wizardResult?.preset,
              tlsFingerprint: wizardResult?.fingerprint ?? TlsFingerprint.firefox,
              muxEnabled: wizardResult?.muxEnabled ?? false,
              ruDirectRouting: wizardResult?.ruDirectRouting ?? false,
            );
        imported++;
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted) return;
    Navigator.pop(context, imported);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import profiles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: item.selected,
                          onChanged: _importing ? null : (v) => setState(() => item.selected = v ?? false),
                          title: Text(item.candidate.type == ProfileType.link ? 'Config link' : 'Subscription URL'),
                        ),
                        TextField(
                          controller: item.nameController,
                          enabled: !_importing,
                          decoration: const InputDecoration(labelText: 'Profile name'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          FilledButton.icon(
            onPressed: _importing ? null : _importSelected,
            icon: const Icon(Icons.download_rounded),
            label: Text(_importing ? 'Importing…' : 'Import selected'),
          ),
        ],
      ),
    );
  }
}

class _EditableCandidate {
  _EditableCandidate({required this.candidate, required this.nameController, required this.selected});
  final ProfileImportCandidate candidate;
  final TextEditingController nameController;
  bool selected;
}

Future<int?> showProfileImportSheet(BuildContext context, List<ProfileImportCandidate> candidates) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProfileImportSheet(candidates: candidates),
  );
}
