import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../providers/vpn_providers.dart';
import '../screens/censorship_wizard_screen.dart';
import '../widgets/animated_entrance.dart';
import '../l10n/app_localizations.dart';
import '../widgets/transport_stack_chip.dart';

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
        SnackBar(content: Text(AppLocalizations.of(context).configNameLinkRequired)),
      );
      return;
    }

    if (_type == ProfileType.link && !V2rayBox().isValidConfigLink(link)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).configInvalidLink)));
      return;
    }

    final wizardResult = await Navigator.of(context).push<CensorshipWizardResult>(
      MaterialPageRoute(
        builder: (_) => CensorshipWizardScreen(
          profileName: name,
          configLink: link,
          profileType: _type,
        ),
      ),
    );

    await ref.read(profilesProvider.notifier).addProfile(
          name: name,
          configLink: wizardResult?.updatedLink ?? link,
          type: _type,
          censorshipModeEnabled: wizardResult?.enabled ?? false,
          transportPreset: wizardResult?.preset,
          tlsFingerprint:
              wizardResult?.fingerprint ?? TlsFingerprint.firefox,
          muxEnabled: wizardResult?.muxEnabled ?? false,
          ruDirectRouting: wizardResult?.ruDirectRouting ?? false,
        );

    _nameController.clear();
    _linkController.clear();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).configProfileAdded)));
    }
  }

  Future<void> _editCensorship(Profile profile) async {
    final result = await Navigator.of(context).push<CensorshipWizardResult>(
      MaterialPageRoute(
        builder: (_) => CensorshipWizardScreen(
          profileName: profile.name,
          configLink: profile.configLink,
          profileType: profile.type,
          initial: profile,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final updated = profile.copyWith(
      configLink: result.updatedLink ?? profile.configLink,
      censorshipModeEnabled: result.enabled,
      transportPreset: result.preset,
      clearTransportPreset: !result.enabled,
      tlsFingerprint: result.fingerprint,
      muxEnabled: result.muxEnabled,
      ruDirectRouting: result.ruDirectRouting,
    );
    await ref.read(profilesProvider.notifier).updateProfile(updated);
    if (ref.read(selectedProfileProvider)?.id == profile.id) {
      await ref.read(selectedProfileProvider.notifier).select(updated);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).configCensorshipUpdated)),
    );
  }

  Future<void> _toggleDisableSocksInjection(Profile profile) async {
    if (profile.type != ProfileType.link) return;
    final updated = profile.copyWith(disableSocksInjection: !profile.disableSocksInjection);
    await ref.read(profilesProvider.notifier).updateProfile(updated);
    if (ref.read(selectedProfileProvider)?.id == profile.id) {
      await ref.read(selectedProfileProvider.notifier).select(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.configAddProfile,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.configAddProfileSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('profile_name_field'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.configProfileName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('profile_link_field'),
                    controller: _linkController,
                    decoration: InputDecoration(
                      labelText: _type == ProfileType.link
                          ? l10n.configLinkLabel : l10n.configSubscriptionUrl,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ProfileType>(
                    segments: [
                      ButtonSegment(
                        value: ProfileType.link,
                        label: Text(l10n.configLink),
                        icon: const Icon(Icons.link),
                      ),
                      ButtonSegment(
                        value: ProfileType.subscription,
                        label: Text(l10n.configSubscription),
                        icon: const Icon(Icons.rss_feed_outlined),
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
                    label: Text(l10n.configAddProfile),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text(
            l10n.configSavedProfiles,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        if (profiles.isEmpty)
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: Card(
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
                      l10n.configNoProfiles,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.configNoProfilesHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...profiles.asMap().entries.map((entry) {
            final index = entry.key;
            final profile = entry.value;
            final selected = selectedProfile?.id == profile.id;
            return FadeSlideIn(
              delay: Duration(milliseconds: 120 + index * 60),
              child: Padding(
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.type == ProfileType.link
                              ? l10n.configDirectLink
                              : profile.autoSelectBestServer
                                  ? (profile.selectedServerName != null
                                        ? 'Automatic · ${profile.selectedServerName}'
                                        : l10n.configSubscriptionAutomatic)
                                  : profile.selectedServerName != null
                                      ? 'Subscription · ${profile.selectedServerName}'
                                      : l10n.configSubscription,
                        ),
                        if (profile.censorshipModeEnabled) ...[
                          const SizedBox(height: 6),
                          TransportStackChip(profile: profile, compact: true),
                        ],
                        if (profile.type == ProfileType.link && profile.disableSocksInjection) ...[
                          const SizedBox(height: 6),
                          Text(l10n.socksDisableInjection, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.tertiary)),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.configCensorshipModeTooltip,
                          icon: const Icon(Icons.shield_outlined),
                          onPressed: () => _editCensorship(profile),
                        ),
                        if (profile.type == ProfileType.link)
                          IconButton(
                            tooltip: l10n.socksDisableInjection,
                            icon: Icon(profile.disableSocksInjection ? Icons.lock_open_outlined : Icons.build_circle_outlined, color: profile.disableSocksInjection ? scheme.tertiary : null),
                            onPressed: () => _toggleDisableSocksInjection(profile),
                          ),
                        if (selected)
                          Icon(Icons.check_circle, color: scheme.primary),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            ref
                                .read(profilesProvider.notifier)
                                .removeProfile(profile.id);
                            if (selectedProfile?.id == profile.id) {
                              ref
                                  .read(selectedProfileProvider.notifier)
                                  .clear();
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      final matches = ref
                          .read(profilesProvider)
                          .where((p) => p.id == profile.id);
                      final picked =
                          matches.isEmpty ? profile : matches.first;
                      ref
                          .read(selectedProfileProvider.notifier)
                          .select(picked);
                    },
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
