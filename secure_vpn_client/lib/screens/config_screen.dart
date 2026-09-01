import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  ProfileType _type = ProfileType.link;

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _addProfile() async {
    final name = _nameController.text.trim();
    final link = _linkController.text.trim();
    if (name.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and config link are required')),
      );
      return;
    }

    if (_type == ProfileType.link && !V2rayBox().isValidConfigLink(link)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid VPN config link')));
      return;
    }

    await ref
        .read(profilesProvider.notifier)
        .addProfile(name: name, configLink: link, type: _type);

    _nameController.clear();
    _linkController.clear();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile added')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paste a share link or subscription URL',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('profile_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Profile name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('profile_link_field'),
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: _type == ProfileType.link
                        ? 'Config link (vless://, hy2://, tuic://, …)'
                        : 'Subscription URL',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ProfileType>(
                  segments: const [
                    ButtonSegment(
                      value: ProfileType.link,
                      label: Text('Link'),
                      icon: Icon(Icons.link),
                    ),
                    ButtonSegment(
                      value: ProfileType.subscription,
                      label: Text('Subscription'),
                      icon: Icon(Icons.rss_feed_outlined),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) {
                    setState(() => _type = selection.first);
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('add_profile_button'),
                  onPressed: _addProfile,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add profile'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Saved profiles',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (profiles.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No profiles yet',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a link or subscription to get started',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...profiles.map((profile) {
            final selected = selectedProfile?.id == profile.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: selected
                    ? scheme.primaryContainer.withValues(alpha: 0.45)
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    foregroundColor: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    child: Icon(
                      profile.type == ProfileType.link
                          ? Icons.link
                          : Icons.rss_feed_outlined,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    profile.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    profile.type == ProfileType.link
                        ? 'Direct link'
                        : profile.autoSelectBestServer
                        ? (profile.selectedServerName != null
                              ? 'Automatic · ${profile.selectedServerName}'
                              : 'Subscription · Automatic')
                        : profile.selectedServerName != null
                        ? 'Subscription · ${profile.selectedServerName}'
                        : 'Subscription',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Icon(Icons.check_circle, color: scheme.primary),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          ref
                              .read(profilesProvider.notifier)
                              .removeProfile(profile.id);
                          if (selectedProfile?.id == profile.id) {
                            ref.read(selectedProfileProvider.notifier).clear();
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // Prefer latest persisted copy (includes server selection).
                    final matches = ref
                        .read(profilesProvider)
                        .where((p) => p.id == profile.id);
                    final selected =
                        matches.isEmpty ? profile : matches.first;
                    ref.read(selectedProfileProvider.notifier).select(selected);
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}
